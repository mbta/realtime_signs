defmodule Engine.Departures do
  @moduledoc """
  Tracks how long ago a train departed from any given stop for use with Headways
  """
  use GenServer
  require Logger
  require Signs.Utilities.SignsConfig

  @type t :: %{
          scheduled_headways_engine: module(),
          time_fetcher: (() -> DateTime.t()),
          stops_with_trains: %{String.t() => String.t()},
          departures: %{
            String.t() => [DateTime.t()]
          }
        }
  @headway_reset_time {3, 0, 0}

  def start_link(opts \\ []) do
    gen_server_name = opts[:gen_server_name] || __MODULE__
    engine_opts = Keyword.delete(opts, :gen_server_name)
    GenServer.start_link(__MODULE__, engine_opts, name: gen_server_name)
  end

  def init(opts) do
    time_zone = Application.get_env(:realtime_signs, :time_zone)
    scheduled_headways_engine = opts[:scheduled_headways_engine] || Engine.ScheduledHeadways
    time_fetcher = opts[:time_fetcher] || fn -> Timex.now(time_zone) end

    reset_time = reset_time(time_fetcher.())
    schedule_headways_reset(reset_time)

    {:ok,
     %{
       scheduled_headways_engine: scheduled_headways_engine,
       time_fetcher: time_fetcher,
       stops_with_trains: %{},
       departures: %{}
     }}
  end

  def get_last_departure(pid \\ __MODULE__, stop_id) do
    GenServer.call(pid, {:get_last_departure, stop_id})
  end

  @spec update_train_state(
          GenServer.server(),
          %{String.t() => String.t()},
          MapSet.t(String.t()),
          DateTime.t()
        ) :: :ok
  def update_train_state(
        pid \\ __MODULE__,
        stops_with_trains,
        vehicles_running_revenue_trips,
        current_time
      ) do
    GenServer.call(
      pid,
      {:update_train_state, stops_with_trains, vehicles_running_revenue_trips, current_time}
    )
  end

  @spec get_headways(GenServer.server(), String.t()) :: Headway.ScheduleHeadway.headway_range()
  def get_headways(pid \\ __MODULE__, stop_id) do
    GenServer.call(pid, {:get_headways, stop_id})
  end

  def handle_call({:get_last_departure, stop_id}, _from, state) do
    last_departure = state[:departures][stop_id] |> List.wrap() |> List.first()
    {:reply, last_departure, state}
  end

  def handle_call(
        {:update_train_state, stops_with_trains, vehicles_running_revenue_trips, current_time},
        _from,
        state
      ) do
    new_departure_stops =
      Enum.reduce(state[:stops_with_trains], [], fn {stop_id, vehicle_id}, acc ->
        if !is_nil(vehicle_id) and stops_with_trains[stop_id] != vehicle_id and
             vehicle_id in vehicles_running_revenue_trips do
          [stop_id | acc]
        else
          acc
        end
      end)

    new_departures =
      Enum.reduce(new_departure_stops, state[:departures], fn stop, acc ->
        add_departure(acc, stop, current_time)
      end)

    new_state = %{state | departures: new_departures, stops_with_trains: stops_with_trains}

    {:reply, :ok, new_state}
  end

  def handle_call({:get_headways, stop_id}, _from, state) do
    current_time = state.time_fetcher.()

    {first_departure, last_departure} =
      state.scheduled_headways_engine.get_first_last_departures(stop_id)

    headways =
      if (!is_nil(first_departure) and DateTime.compare(current_time, first_departure) == :lt) or
           (!is_nil(last_departure) and DateTime.compare(current_time, last_departure) == :gt) do
        :none
      else
        case state[:departures][stop_id] do
          [_one_departure] ->
            state.scheduled_headways_engine.get_headways(stop_id)

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
      end

    {:reply, headways, state}
  end

  def handle_info(:daily_reset, state) do
    reset_time = reset_time(state.time_fetcher.())
    schedule_headways_reset(reset_time)

    Logger.info("daily_reset: Resetting headway observations")
    {:noreply, %{state | departures: %{}, stops_with_trains: MapSet.new()}}
  end

  def handle_info(_, _) do
    {:noreply, %{}}
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
  defp translate_terminal_stop_id("70161"), do: "70160"
  defp translate_terminal_stop_id(stop_id), do: stop_id

  def schedule_headways_reset(pid \\ __MODULE__, interval) do
    Process.send_after(pid, :daily_reset, interval)
    nil
  end

  defp reset_time(current_time) do
    {hour, minute, second} = @headway_reset_time

    current_time
    |> Timex.shift(days: 1)
    |> Timex.set(hour: hour, minute: minute, second: second)
    |> Timex.diff(current_time, :milliseconds)
  end
end
