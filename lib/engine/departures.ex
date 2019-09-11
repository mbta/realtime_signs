defmodule Engine.Departures do
  @moduledoc """
  Tracks how long ago a train departed from any given stop for use with Headways
  """
  use GenServer
  require Logger
  require Signs.Utilities.SignsConfig

  @type t :: %{
          stops_with_trains: MapSet.t(String.t()),
          departures: %{
            String.t() => [DateTime.t()]
          }
        }

  def start_link(opts \\ []) do
    gen_server_name = opts[:gen_server_name] || __MODULE__
    engine_opts = Keyword.delete(opts, :gen_server_name)
    GenServer.start_link(__MODULE__, engine_opts, name: gen_server_name)
  end

  def init(_opts) do
    {:ok, %{stops_with_trains: MapSet.new(), departures: %{}}}
  end

  def get_last_departure(pid \\ __MODULE__, stop_id) do
    GenServer.call(pid, {:get_last_departure, stop_id})
  end

  @spec update_train_state(GenServer.server(), [String.t()], DateTime.t()) :: :ok
  def update_train_state(pid \\ __MODULE__, stops_with_trains, current_time) do
    GenServer.call(pid, {:update_train_state, stops_with_trains, current_time})
  end

  @spec get_headways(GenServer.server(), String.t()) :: Headway.ScheduleHeadway.headway_range()
  def get_headways(pid \\ __MODULE__, stop_id) do
    GenServer.call(pid, {:get_headways, stop_id})
  end

  def handle_call({:get_last_departure, stop_id}, _from, state) do
    last_departure = state[:departures][stop_id] |> List.wrap() |> List.first()
    {:reply, last_departure, state}
  end

  def handle_call({:update_train_state, stops_with_trains, current_time}, _from, state) do
    stops_with_trains = MapSet.new(stops_with_trains)

    new_departure_stops =
      state[:stops_with_trains]
      |> MapSet.difference(stops_with_trains)

    new_departures =
      Enum.reduce(new_departure_stops, state[:departures], fn stop, acc ->
        add_departure(acc, stop, current_time)
      end)

    new_state = %{departures: new_departures, stops_with_trains: stops_with_trains}

    {:reply, :ok, new_state}
  end

  def handle_call({:get_headways, stop_id}, _from, state) do
    headways =
      case state[:departures][stop_id] do
        [_one_departure] ->
          {nil, nil}

        [one_departure, two_departure] ->
          {Timex.diff(one_departure, two_departure, :minutes), nil}

        [one_departure, two_departure, three_departure | _] ->
          headway_sort(
            {Timex.diff(one_departure, two_departure, :minutes),
             Timex.diff(two_departure, three_departure, :minutes)}
          )

        _ ->
          :none
      end

    {:reply, headways, state}
  end

  @spec add_departure(%{String.t() => [DateTime.t()]}, String.t(), DateTime.t()) :: %{
          String.t() => [DateTime.t()]
        }
  defp add_departure(departures, stop_id, time) do
    translated_stop_id = translate_terminal_stop_id(stop_id)

    new_times_for_stop =
      departures[translated_stop_id]
      |> List.wrap()
      |> (fn stop_departures ->
            case stop_departures do
              [first | rest] ->
                if Timex.diff(time, first, :minutes) > 2 do
                  [time | stop_departures]
                else
                  [time | rest]
                end

              [] ->
                [time]
            end
          end).()
      |> Enum.take(3)

    Map.put(departures, translated_stop_id, new_times_for_stop)
  end

  @spec headway_sort({non_neg_integer, non_neg_integer}) :: {non_neg_integer, non_neg_integer}
  defp headway_sort({first, second}) when first > second do
    {second, first}
  end

  defp headway_sort({first, second}) when first <= second do
    {first, second}
  end

  @spec translate_terminal_stop_id(String.t()) :: String.t()
  defp translate_terminal_stop_id("Alewife-" <> _), do: "70061"
  defp translate_terminal_stop_id("Braintree-" <> _), do: "70105"
  defp translate_terminal_stop_id("Forest Hills-" <> _), do: "70001"
  defp translate_terminal_stop_id("Oak Grove-" <> _), do: "70036"
  defp translate_terminal_stop_id(stop_id), do: stop_id
end
