defmodule Engine.ObservedHeadways do
  use GenServer

  @min_headway 6
  @max_headway 20
  @max_spread 10
  @default_recent_headway 3600

  @type t :: %__MODULE__{
          recent_headways: %{String.t() => non_neg_integer()},
          stops: %{String.t() => String.t()}
        }

  @enforce_keys [:recent_headways, :stops]
  defstruct @enforce_keys

  @spec get_headways(String.t()) :: {non_neg_integer(), non_neg_integer()}
  def get_headways(stop_id) do
    GenServer.call(__MODULE__, {:get_headways, stop_id})
  end

  def start_link(opts \\ []) do
    name = opts[:gen_server_name] || __MODULE__
    engine_opts = Keyword.delete(opts, :gen_server_name)
    GenServer.start_link(__MODULE__, engine_opts, name: name)
  end

  def init(_opts \\ []) do
    signs_using_observed_headway =
      Signs.Utilities.SignsConfig.children_config() |> Enum.filter(& &1["headway_terminal_ids"])

    stop_ids_to_terminals =
      signs_using_observed_headway
      |> Enum.map(fn sign ->
        {
          sign["source_config"] |> hd |> hd |> Map.fetch!("stop_id"),
          sign["headway_terminal_ids"]
        }
      end)
      |> Map.new()

    initial_state = %__MODULE__{
      stops: stop_ids_to_terminals,
      recent_headways: %{
        "alewife" => [@default_recent_headway],
        "ashmont" => [@default_recent_headway],
        "bowdoin" => [@default_recent_headway],
        "braintree" => [@default_recent_headway],
        "forest_hills" => [@default_recent_headway],
        "oak_grove" => [@default_recent_headway],
        "wonderland" => [@default_recent_headway]
      }
    }

    {:ok, initial_state}
  end

  def handle_call({:get_headways, stop_id}, _from, state) do
    terminal_ids = Map.fetch!(state.stops, stop_id)

    headways =
      Enum.map(terminal_ids, fn terminal_id -> Map.fetch!(state.recent_headways, terminal_id) end)

    pessimistic_min =
      headways |> Enum.map(&Enum.min/1) |> Enum.max() |> Kernel./(60.0) |> Kernel.round()

    pessimistic_max =
      headways |> Enum.map(&Enum.max/1) |> Enum.max() |> Kernel./(60.0) |> Kernel.round()

    pessimistic_min = Enum.max([pessimistic_min, @min_headway])
    pessimistic_min = Enum.min([pessimistic_min, @max_headway])
    pessimistic_max = Enum.max([pessimistic_max, @min_headway])
    pessimistic_max = Enum.min([pessimistic_max, @max_headway])

    pessimistic_min =
      if pessimistic_min < pessimistic_max - @max_spread do
        pessimistic_max - @max_spread
      else
        pessimistic_min
      end

    {:reply, {pessimistic_min, pessimistic_max}, state}
  end
end
