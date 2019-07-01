defmodule Engine.ObservedHeadways do
  use GenServer

  @min_headway 4
  @max_headway 20
  @max_spread 10
  @default_recent_headway 3600
  @fetch_ms 60_000
  @terminal_ids [
    "alewife",
    "ashmont",
    "bowdoin",
    "braintree",
    "forest_hills",
    "oak_grove",
    "wonderland"
  ]

  @type state :: %__MODULE__{
          recent_headways: %{String.t() => non_neg_integer()},
          stops_to_terminal_ids: %{String.t() => String.t()}
        }

  @enforce_keys [:recent_headways, :stops_to_terminal_ids]
  defstruct @enforce_keys

  @spec get_headways(String.t()) :: {non_neg_integer(), non_neg_integer()}
  def get_headways(stop_id) do
    GenServer.call(__MODULE__, {:get_headways, stop_id})
  end

  def start_link(opts \\ []) do
    gen_server_name = opts[:gen_server_name] || __MODULE__
    engine_opts = Keyword.delete(opts, :gen_server_name)
    GenServer.start_link(__MODULE__, engine_opts, name: gen_server_name)
  end

  def init(_opts \\ []) do
    signs_using_observed_headway =
      Signs.Utilities.SignsConfig.children_config() |> Enum.filter(& &1["headway_terminal_ids"])

    stop_ids_to_terminals =
      signs_using_observed_headway
      |> Map.new(fn sign ->
        {
          Signs.Utilities.SignsConfig.get_stop_ids_for_sign(sign) |> hd,
          sign["headway_terminal_ids"]
        }
      end)

    initial_state = %__MODULE__{
      stops_to_terminal_ids: stop_ids_to_terminals,
      recent_headways: Map.new(@terminal_ids, &{&1, [@default_recent_headway]})
    }

    schedule_fetch()
    {:ok, initial_state}
  end

  def handle_call({:get_headways, stop_id}, _from, state) do
    {:reply, estimate_headways_for_stop(stop_id, state), state}
  end

  def handle_info(:fetch_headways, state) do
    schedule_fetch(@fetch_ms)

    fetcher = Application.get_env(:realtime_signs, :observed_headway_fetcher)

    state =
      case fetcher.fetch() do
        {:ok, new_headways} -> %__MODULE__{state | recent_headways: new_headways}
        :error -> state
      end

    {:noreply, state}
  end

  @spec estimate_headways_for_stop(String.t(), state()) :: {non_neg_integer, non_neg_integer}
  defp estimate_headways_for_stop(stop_id, state) do
    headways = terminal_headways_for_stop(stop_id, state)

    optimistic_min =
      headways |> Enum.map(&Enum.min/1) |> Enum.min() |> Kernel./(60.0) |> Kernel.round()

    pessimistic_max =
      headways |> Enum.map(&Enum.max/1) |> Enum.max() |> Kernel./(60.0) |> Kernel.round()

    optimistic_min = Enum.max([optimistic_min, @min_headway])
    optimistic_min = Enum.min([optimistic_min, @max_headway])
    pessimistic_max = Enum.max([pessimistic_max, @min_headway])
    pessimistic_max = Enum.min([pessimistic_max, @max_headway])

    optimistic_min =
      if optimistic_min < pessimistic_max - @max_spread do
        pessimistic_max - @max_spread
      else
        optimistic_min
      end

    {optimistic_min, pessimistic_max}
  end

  @spec schedule_fetch(non_neg_integer()) :: reference()
  defp schedule_fetch(ms \\ 0) do
    Process.send_after(self(), :fetch_headways, ms)
  end

  @spec terminal_headways_for_stop(String.t(), state()) :: [non_neg_integer]
  defp terminal_headways_for_stop(stop_id, state) do
    terminal_ids = Map.fetch!(state.stops_to_terminal_ids, stop_id)
    Enum.map(terminal_ids, fn terminal_id -> Map.fetch!(state.recent_headways, terminal_id) end)
  end
end
