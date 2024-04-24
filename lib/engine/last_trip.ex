defmodule Engine.LastTrip do
  @behaviour Engine.LastTripAPI
  use GenServer
  require Logger

  @recent_departures_table :recent_departures
  @last_trips_table :last_trips
  @hour_in_seconds 3600

  @type state :: %{
          last_modified: nil,
          recent_departures: :ets.tab(),
          last_trips: :ets.tab()
        }

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def get_recent_departures(recent_departures_table \\ @recent_departures_table, stop_id) do
    case :ets.lookup(recent_departures_table, stop_id) do
      [{_, :none}] -> nil
      [{^stop_id, departures}] -> departures
      _ -> nil
    end
  end

  @impl true
  def is_last_trip?(last_trips_table \\ @last_trips_table, trip_id) do
    case :ets.lookup(last_trips_table, trip_id) do
      [{_, :none}] -> false
      [{^trip_id, _timestamp}] -> true
      _ -> false
    end
  end

  def update_last_trips(last_trips) do
    GenServer.cast(__MODULE__, {:update_last_trips, last_trips})
  end

  def update_recent_departures(new_recent_departures) do
    GenServer.cast(__MODULE__, {:update_recent_departures, new_recent_departures})
  end

  @impl true
  def init(_) do
    schedule_clean(self())

    state = %{
      recent_departures: @recent_departures_table,
      last_trips: @last_trips_table,
      last_modified: nil
    }

    create_tables(state)
    {:ok, state}
  end

  def create_tables(state) do
    :ets.new(state.recent_departures, [:named_table, read_concurrency: true])
    :ets.new(state.last_trips, [:named_table, read_concurrency: true])
  end

  @impl true
  def handle_cast({:update_last_trips, last_trips}, %{last_trips: last_trips_table} = state) do
    current_time = Timex.now()

    last_trips =
      Enum.map(last_trips, fn {trip_id, route_id} -> {trip_id, route_id, current_time} end)

    :ets.insert(last_trips_table, last_trips)

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:update_recent_departures, new_recent_departures},
        %{recent_departures: recent_departures_table} = state
      ) do
    current_recent_departures =
      :ets.tab2list(recent_departures_table)
      |> Stream.map(&{elem(&1, 0), elem(&1, 1)})
      |> Map.new()

    Enum.reduce(new_recent_departures, current_recent_departures, fn {stop_id, trip_id, route_id,
                                                                      departure_time},
                                                                     acc ->
      Map.get_and_update(acc, {stop_id, route_id}, fn recent_departures ->
        if recent_departures do
          {recent_departures, Map.put(recent_departures, trip_id, departure_time)}
        else
          {recent_departures, Map.new([{trip_id, departure_time}])}
        end
      end)
      |> elem(1)
    end)
    |> Map.to_list()
    |> then(&:ets.insert(recent_departures_table, &1))

    {:noreply, state}
  end

  @impl true
  def handle_info(:clean_old_data, state) do
    schedule_clean(self())
    clean_last_trips(state)
    clean_recent_departures(state)

    {:noreply, state}
  end

  defp clean_last_trips(state) do
    :ets.tab2list(state.last_trips)
    |> Enum.each(fn {trip_id, timestamp} ->
      if Timex.diff(Timex.now(), timestamp, :seconds) > @hour_in_seconds * 2 do
        :ets.delete(state.last_trips, trip_id)
      end
    end)
  end

  defp clean_recent_departures(state) do
    current_time = Timex.now()

    :ets.tab2list(state.recent_departures)
    |> Enum.each(fn {key, departures} ->
      departures_within_last_hour =
        Map.filter(departures, fn {_, departed_time} ->
          DateTime.to_unix(current_time) - departed_time <= @hour_in_seconds
        end)

      :ets.insert(state.recent_departures, {key, departures_within_last_hour})
    end)
  end

  defp schedule_clean(pid) do
    Process.send_after(pid, :clean_old_data, 1_000)
  end
end
