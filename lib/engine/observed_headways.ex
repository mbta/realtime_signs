defmodule Engine.ObservedHeadways do
  use GenServer
  require Logger

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
          stop_ids_to_terminal_ids: %{String.t() => String.t()}
        }

  @enforce_keys [:recent_headways, :stop_ids_to_terminal_ids]
  defstruct @enforce_keys

  @spec get_headways(String.t(), :ets.tab()) :: {non_neg_integer(), non_neg_integer()}
  def get_headways(stop_id, ets_table_name \\ __MODULE__) do
    headways = terminal_headways_for_stop(stop_id, ets_table_name)

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

  def start_link(opts \\ []) do
    gen_server_name = opts[:gen_server_name] || __MODULE__
    engine_opts = Keyword.delete(opts, :gen_server_name)
    GenServer.start_link(__MODULE__, engine_opts, name: gen_server_name)
  end

  def init(opts \\ []) do
    ets_table_name = opts[:ets_table_name] || __MODULE__

    ^ets_table_name =
      :ets.new(ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

    signs_using_observed_headway =
      Signs.Utilities.SignsConfig.children_config() |> Enum.filter(& &1["headway_terminal_ids"])

    stop_ids_to_terminal_ids =
      signs_using_observed_headway
      |> Map.new(fn sign ->
        {
          Signs.Utilities.SignsConfig.get_stop_ids_for_sign(sign) |> hd,
          sign["headway_terminal_ids"]
        }
      end)

    recent_headways = Map.new(@terminal_ids, &{&1, [@default_recent_headway]})

    :ets.insert(ets_table_name, {:stop_ids_to_terminal_ids, stop_ids_to_terminal_ids})
    :ets.insert(ets_table_name, {:recent_headways, recent_headways})

    schedule_fetch()
    {:ok, ets_table_name}
  end

  def handle_info(:fetch_headways, ets_table_name) do
    schedule_fetch(@fetch_ms)

    fetcher = Application.get_env(:realtime_signs, :observed_headway_fetcher)

    case fetcher.fetch() do
      {:ok, new_headways} ->
        :ets.insert(ets_table_name, {:recent_headways, new_headways})

      {:error, message} ->
        Logger.warn(message)
    end

    {:noreply, ets_table_name}
  end

  @spec schedule_fetch(non_neg_integer()) :: reference()
  defp schedule_fetch(ms \\ 0) do
    Process.send_after(self(), :fetch_headways, ms)
  end

  @spec terminal_headways_for_stop(String.t(), :ets.tab()) :: [non_neg_integer]
  defp terminal_headways_for_stop(stop_id, ets_table_name) do
    terminal_id_hash = :ets.lookup_element(ets_table_name, :stop_ids_to_terminal_ids, 2)
    recent_headways_hash = :ets.lookup_element(ets_table_name, :recent_headways, 2)

    terminal_ids = Map.fetch!(terminal_id_hash, stop_id)
    Enum.map(terminal_ids, fn terminal_id -> Map.fetch!(recent_headways_hash, terminal_id) end)
  end
end
