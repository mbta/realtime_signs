defmodule Predictions.LastTrip do
  defp get_running_trips(predictions_feed) do
    predictions_feed["entity"]
    |> Stream.map(& &1["trip_update"])
    |> Stream.filter(
      &(&1["trip"]["route_id"] in [
          "Red",
          "Blue",
          "Orange",
          "Green-B",
          "Green-C",
          "Green-D",
          "Green-E",
          "Mattapan"
        ] and &1["trip"]["schedule_relationship"] != "CANCELED")
    )
  end

  def get_last_trips(predictions_feed) do
    get_running_trips(predictions_feed)
    |> Stream.filter(&(&1["trip"]["last_trip"] == true))
    |> Enum.map(& &1["trip"]["trip_id"])
  end

  def get_recent_departures(predictions_feed) do
    predictions_by_trip =
      get_running_trips(predictions_feed)
      |> Enum.map(&{&1["trip"]["trip_id"], &1["stop_time_update"], &1["vehicle"]["id"]})

    for {trip_id, predictions, vehicle_id} <- predictions_by_trip,
        prediction <- predictions do
      vehicle_location = Engine.Locations.for_vehicle(vehicle_id)

      if vehicle_location &&
           (vehicle_location.stop_id == prediction["stop_id"] and
              vehicle_location.status == :stopped_at) do
        {prediction["stop_id"], trip_id, Timex.now()}
      end
    end
    |> Enum.reject(&is_nil/1)
  end
end
