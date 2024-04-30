defmodule Predictions.LastTrip do
  @hour_in_seconds 3600

  defp get_running_trips(predictions_feed) do
    predictions_feed["entity"]
    |> Stream.map(& &1["trip_update"])
    |> Enum.reject(&(&1["trip"]["schedule_relationship"] == "CANCELED"))
  end

  def get_last_trips(predictions_feed) do
    get_running_trips(predictions_feed)
    |> Stream.filter(&(&1["trip"]["last_trip"] == true))
    |> Enum.map(& &1["trip"]["trip_id"])
  end

  def get_recent_departures(predictions_feed) do
    current_time = Timex.now()

    predictions_by_trip =
      get_running_trips(predictions_feed)
      |> Enum.map(&{&1["trip"]["trip_id"], &1["stop_time_update"]})

    for {trip_id, predictions} <- predictions_by_trip,
        prediction <- predictions,
        prediction["departure"] do
      seconds_until_departure = prediction["departure"]["time"] - DateTime.to_unix(current_time)

      if seconds_until_departure in -@hour_in_seconds..0 do
        {prediction["stop_id"], trip_id, prediction["departure"]["time"]}
      end
    end
    |> Enum.reject(&is_nil/1)
  end
end
