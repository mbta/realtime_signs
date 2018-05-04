defmodule Predictions.Predictions do
  alias Predictions.Prediction
  require Logger

  def get_all(feed_message, current_time) do
    feed_message.entity
    |> Enum.map(& &1.trip_update)
    |> Enum.flat_map(&group_stop_time_updates/1)
    |> Enum.filter(fn {update, _, _} -> update.arrival || update.departure end)
    |> Enum.group_by(fn {update, direction_id, _route_id} -> {update.stop_id, direction_id} end, &prediction_from_update(&1, current_time))
  end

  defp group_stop_time_updates(trip_update) do
    Enum.map(trip_update.stop_time_update, &{&1, trip_update.trip.direction_id, trip_update.trip.route_id})
  end

  defp prediction_from_update({stop_time_update, direction_id, route_id}, current_time) do
    current_time_seconds = DateTime.to_unix(current_time)
    prediction_time = if stop_time_update.departure, do: stop_time_update.departure, else: stop_time_update.arrival

    %Prediction{
      stop_id: stop_time_update.stop_id,
      direction_id: direction_id,
      seconds_until_arrival: max(0, prediction_time.time - current_time_seconds),
      route_id: route_id
    }
  end

  def parse_pb_response(body) do
    GTFS.Realtime.FeedMessage.decode(body)
  end

  @spec sort([Predictions.Prediction.t]) :: [Predictions.Prediction.t]
  def sort(predictions) do
    Enum.sort(predictions, & &1.seconds_until_arrival < &2.seconds_until_arrival)
  end
end
