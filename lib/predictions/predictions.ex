defmodule Predictions.Predictions do
  alias Predictions.Prediction
  require Logger

  @spec get_all(GTFS.Realtime.feed_message, DateTime.t) :: %{optional({String.t(), integer()}) => [Predictions.Prediction.t]}
  def get_all(feed_message, current_time) do
    feed_message.entity
    |> Enum.map(& &1.trip_update)
    |> Enum.flat_map(&group_stop_time_updates/1)
    |> Enum.filter(fn {update, _, _, _} -> update.arrival || update.departure end)
    |> Enum.group_by(fn {update, _last_stop_id, _route_id, direction_id} -> {update.stop_id, direction_id} end, &prediction_from_update(&1, current_time))
  end

  defp group_stop_time_updates(trip_update) do
    Enum.map(trip_update.stop_time_update, &{&1, trip_update.stop_time_update |> Enum.max_by(fn(update) -> if update.arrival, do: update.arrival.time end) |> Map.get(:stop_id), trip_update.trip.route_id, trip_update.trip.direction_id})
  end

  defp prediction_from_update({stop_time_update, last_stop_id, route_id, direction_id}, current_time) do
    current_time_seconds = DateTime.to_unix(current_time)
    prediction_time = if stop_time_update.departure, do: stop_time_update.departure, else: stop_time_update.arrival

    case headsign_for_prediction(route_id, direction_id, last_stop_id) do
      {:ok, headsign} ->
        %Prediction{
                     stop_id: stop_time_update.stop_id,
                     direction_id: direction_id,
                     seconds_until_arrival: max(0, prediction_time.time - current_time_seconds),
                     route_id: route_id,
                     headsign: headsign
                   }
      {:error, :not_found} ->
        Logger.error("Could not find headsign for stop_time_update #{inspect stop_time_update} with last_stop_id #{last_stop_id} on route #{route_id} in direction #{direction_id}")
        nil
    end
  end

  def parse_pb_response(body) do
    GTFS.Realtime.FeedMessage.decode(body)
  end

  @spec sort([Predictions.Prediction.t]) :: [Predictions.Prediction.t]
  def sort(predictions) do
    Enum.sort(predictions, & &1.seconds_until_arrival < &2.seconds_until_arrival)
  end

  @spec headsign_for_prediction(String.t(), 0 | 1, String.t()) :: {:ok, String.t()} | {:error, :not_found}
  defp headsign_for_prediction("Mattapan", 0, _), do: {:ok, "Mattapan"}
  defp headsign_for_prediction("Mattapan", 1, _), do: {:ok, "Ashmont"}
  defp headsign_for_prediction("Orange", 0, _), do: {:ok, "Frst Hills"}
  defp headsign_for_prediction("Orange", 1, _), do: {:ok, "Oak Grove"}
  defp headsign_for_prediction("Blue", 0, _), do: {:ok, "Bowdoin"}
  defp headsign_for_prediction("Blue", 1, _), do: {:ok, "Wonderland"}
  defp headsign_for_prediction("Red", 1, _), do: {:ok, "Alewife"}
  defp headsign_for_prediction("Red", 0, last_stop_id) when last_stop_id in ["70087", "70089", "70091", "70093"], do: {:ok, "Ashmont"}
  defp headsign_for_prediction("Red", 0, last_stop_id) when last_stop_id in ["70097", "70101", "70103", "70105"], do: {:ok, "Braintree"}
  defp headsign_for_prediction("Green-B", 0, _), do: {:ok, "Boston Col"}
  defp headsign_for_prediction("Green-C", 0, _), do: {:ok, "Clvlnd Cir"}
  defp headsign_for_prediction("Green-D", 0, _), do: {:ok, "Riverside"}
  defp headsign_for_prediction("Green-E", 0, _), do: {:ok, "Heath St"}
  defp headsign_for_prediction(_, 1, "70209"), do: {:ok, "Lechmere"}
  defp headsign_for_prediction(_, 1, "70205"), do: {:ok, "North Sta"}
  defp headsign_for_prediction(_, 1, "70201"), do: {:ok, "Govt Ctr"}
  defp headsign_for_prediction(_, 1, "70200"), do: {:ok, "Park St"}
  defp headsign_for_prediction(_, _, _), do: {:error, :not_found}
end
