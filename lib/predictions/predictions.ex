defmodule Predictions.Predictions do
  alias Predictions.Prediction
  require Logger

  @spec get_all(map(), DateTime.t()) :: %{
          optional({String.t(), integer()}) => [Predictions.Prediction.t()]
        }
  def get_all(feed_message, current_time) do
    feed_message["entity"]
    |> Enum.map(& &1["trip_update"])
    |> Enum.flat_map(&group_stop_time_updates/1)
    |> Enum.filter(fn {update, _, _, _} -> update["arrival"] || update["departure"] end)
    |> Enum.group_by(
      fn {update, _last_stop_id, _route_id, direction_id} ->
        {update["stop_id"], direction_id}
      end,
      &prediction_from_update(&1, current_time)
    )
  end

  defp group_stop_time_updates(trip_update) do
    last_stop_id =
      Enum.max_by(trip_update["stop_time_update"], fn update ->
        if update["arrival"], do: update["arrival"]["time"], else: 0
      end)
      |> Map.get("stop_id")

    Enum.map(
      trip_update["stop_time_update"],
      &{&1, last_stop_id, trip_update["trip"]["route_id"], trip_update["trip"]["direction_id"]}
    )
  end

  @spec prediction_from_update(
          {GTFS.Realtime.trip_update_stop_time_update(), String.t(), String.t(), integer()},
          DateTime.t()
        ) :: Prediction.t()
  defp prediction_from_update(
         {stop_time_update, last_stop_id, route_id, direction_id},
         current_time
       ) do
    current_time_seconds = DateTime.to_unix(current_time)

    seconds_until_arrival =
      if stop_time_update["arrival"],
        do: stop_time_update["arrival"]["time"] - current_time_seconds,
        else: nil

    seconds_until_departure =
      if stop_time_update["departure"],
        do: stop_time_update["departure"]["time"] - current_time_seconds,
        else: nil

    %Prediction{
      stop_id: stop_time_update["stop_id"],
      direction_id: direction_id,
      seconds_until_arrival: max(0, seconds_until_arrival),
      seconds_until_departure: max(0, seconds_until_departure),
      route_id: route_id,
      destination_stop_id: last_stop_id,
      stopped?: stop_time_update["stopped?"],
      stops_away: stop_time_update["stops_away"],
      boarding_status: stop_time_update["boarding_status"]
    }
  end

  def parse_json_response("") do
    %{"entity" => []}
  end

  def parse_json_response(body) do
    Poison.Parser.parse!(body)
  end

  @spec sort([Predictions.Prediction.t()], :arrival | :departure) :: [Predictions.Prediction.t()]
  def sort(predictions, :arrival) do
    Enum.sort(
      predictions,
      &compare_predictions(&1, &2, :arrival)
    )
  end

  def sort(predictions, :departure) do
    Enum.sort(
      predictions,
      &compare_predictions(&1, &2, :departure)
    )
  end

  defp compare_predictions(%{stops_away: 0}, _time_two, _) do
    true
  end

  defp compare_predictions(_time_one, %{stops_away: 0}, _) do
    false
  end

  defp compare_predictions(
         %{seconds_until_arrival: time_one},
         %{seconds_until_arrival: time_two},
         :arrival
       ) do
    time_one < time_two
  end

  defp compare_predictions(
         %{seconds_until_departure: time_one},
         %{seconds_until_departure: time_two},
         :departure
       ) do
    time_one < time_two
  end
end
