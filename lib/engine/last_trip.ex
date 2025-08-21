defmodule Engine.LastTrip do
  use GenServer
  require Logger

  @recent_departures_table :recent_departures
  @last_trips_table :last_trips
  @timezone "America/New_York"

  @type state :: %{
          recent_departures: :ets.tab(),
          last_trips: :ets.tab()
        }

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @callback get_recent_departures(String.t()) :: map()
  def get_recent_departures(recent_departures_table \\ @recent_departures_table, stop_id) do
    case :ets.lookup(recent_departures_table, stop_id) do
      [{^stop_id, departures}] -> departures
      _ -> []
    end
  end

  @callback is_last_trip?(String.t()) :: boolean()
  def is_last_trip?(last_trips_table \\ @last_trips_table, trip_id) do
    case :ets.lookup(last_trips_table, trip_id) do
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
    schedule_loop(self())

    state = %{
      recent_departures: @recent_departures_table,
      last_trips: @last_trips_table
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

    last_trips = Enum.map(last_trips, fn trip_id -> {trip_id, current_time} end)

    :ets.insert(last_trips_table, last_trips)

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:update_recent_departures, new_recent_departures},
        %{recent_departures: recent_departures_table} = state
      ) do
    current_recent_departures = :ets.tab2list(recent_departures_table) |> Map.new()

    Enum.reduce(new_recent_departures, current_recent_departures, fn {stop_id, trip_id,
                                                                      departure_time},
                                                                     acc ->
      Map.update(acc, stop_id, %{trip_id => departure_time}, fn recent_departures ->
        Map.put(recent_departures, trip_id, departure_time)
      end)
    end)
    |> Map.to_list()
    |> then(&:ets.insert(recent_departures_table, &1))

    {:noreply, state}
  end

  @impl true
  def handle_info(:loop, state) do
    schedule_loop(self())

    {:ok, current_time_est} = DateTime.utc_now() |> DateTime.shift_zone(@timezone)

    if current_time_est.hour == 4 and current_time_est.minute == 0 do
      clean_tables(state)
    end

    {:noreply, state}
  end

  defp clean_tables(state) do
    :ets.delete_all_objects(state.last_trips)
    :ets.delete_all_objects(state.recent_departures)
  end

  defp schedule_loop(pid) do
    Process.send_after(pid, :loop, 1_000)
  end
end
