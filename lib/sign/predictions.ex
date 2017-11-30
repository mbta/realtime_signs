defmodule Sign.Predictions do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(state) do
    schedule_download()
    {:ok, state}
  end

  def handle_info(:download, state) do
    raw_vehicle_positions = HTTPoison.get!("https://s3.amazonaws.com/mbta-gtfs-s3/VehiclePositions.pb")
    raw_trip_updates = HTTPoison.get!("https://s3.amazonaws.com/mbta-gtfs-s3/TripUpdates.pb")
    vehicle_positions = GTFS.Realtime.FeedMessage.decode(raw_vehicle_positions.body)
    trip_updates = GTFS.Realtime.FeedMessage.decode(raw_trip_updates.body)
    current_time = Timex.now

    Sign.State.update(trip_updates, vehicle_positions, current_time)

    schedule_download()
    {:noreoly, state}
  end

  defp schedule_download() do
    Process.send_after(self(), :download, 5 * 1000)
  end
end
