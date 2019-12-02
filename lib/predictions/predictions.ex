defmodule Predictions.Predictions do
  alias Predictions.Prediction
  require Logger

  @spec get_all(map(), DateTime.t()) ::
          {%{
             optional({String.t(), integer()}) => [Predictions.Prediction.t()]
           }, MapSet.t(String.t())}
  def get_all(feed_message, current_time) do
    predictions =
      feed_message["entity"]
      |> Enum.map(& &1["trip_update"])
      |> Enum.reject(&(&1["trip"]["schedule_relationship"] == "CANCELED"))
      |> Enum.flat_map(&transform_stop_time_updates/1)
      |> Enum.filter(fn {update, _, _, _, _, _, _, _} ->
        update["arrival"] || update["departure"] || update["passthrough_time"]
      end)
      |> Enum.map(&prediction_from_update(&1, current_time))

    vehicles_running_revenue_trips =
      predictions
      |> Enum.filter(& &1.revenue_trip?)
      |> Enum.map(& &1.vehicle_id)
      |> MapSet.new()

    {Enum.group_by(predictions, fn prediction ->
       {prediction.stop_id, prediction.direction_id}
     end), vehicles_running_revenue_trips}
  end

  @spec transform_stop_time_updates(map()) :: [
          {map(), String.t(), String.t(), integer(), String.t(), [String.t()] | nil, boolean(),
           String.t() | nil}
        ]
  defp transform_stop_time_updates(trip_update) do
    last_stop_id =
      Enum.max_by(trip_update["stop_time_update"], fn update ->
        if update["arrival"], do: update["arrival"]["time"], else: 0
      end)
      |> Map.get("stop_id")

    consist =
      if trip_update["vehicle"] && trip_update["vehicle"]["consist"] do
        Enum.map(trip_update["vehicle"]["consist"], & &1["label"])
      else
        nil
      end

    revenue_trip? =
      Enum.any?(trip_update["stop_time_update"], &(&1["schedule_relationship"] != "SKIPPED"))

    vehicle_id = get_in(trip_update, ["vehicle", "id"])

    Enum.map(
      trip_update["stop_time_update"],
      &{&1, last_stop_id, trip_update["trip"]["route_id"], trip_update["trip"]["direction_id"],
       trip_update["trip"]["trip_id"], consist, revenue_trip?, vehicle_id}
    )
  end

  @spec prediction_from_update(
          {map(), String.t(), String.t(), integer(), Predictions.Prediction.trip_id(),
           [String.t()] | nil, boolean(), String.t() | nil},
          DateTime.t()
        ) :: Prediction.t()
  defp prediction_from_update(
         {stop_time_update, last_stop_id, route_id, direction_id, trip_id, consist, revenue_trip?,
          vehicle_id},
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

    seconds_until_passthrough =
      if stop_time_update["passthrough_time"],
        do: stop_time_update["passthrough_time"] - current_time_seconds,
        else: nil

    %Prediction{
      stop_id: stop_time_update["stop_id"],
      direction_id: direction_id,
      seconds_until_arrival: max(0, seconds_until_arrival),
      seconds_until_departure: max(0, seconds_until_departure),
      seconds_until_passthrough: max(0, seconds_until_passthrough),
      schedule_relationship:
        translate_schedule_relationship(stop_time_update["schedule_relationship"]),
      route_id: route_id,
      trip_id: trip_id,
      destination_stop_id: last_stop_id,
      stopped?: stop_time_update["stopped?"],
      stops_away: stop_time_update["stops_away"],
      boarding_status: stop_time_update["boarding_status"],
      new_cars?: consist_is_new?(consist),
      revenue_trip?: revenue_trip?,
      vehicle_id: vehicle_id
    }
  end

  def parse_json_response("") do
    %{"entity" => []}
  end

  def parse_json_response(body) do
    Poison.Parser.parse!(body)
  end

  @spec consist_is_new?([String.t()] | nil) :: boolean()
  defp consist_is_new?(nil) do
    false
  end

  defp consist_is_new?(consist) do
    Enum.any?(consist, fn car ->
      case Integer.parse(car) do
        :error -> false
        {n, _remaining} -> 1400 <= n and n <= 1551
      end
    end)
  end

  @spec translate_schedule_relationship(String.t()) :: :skipped | :scheduled
  defp translate_schedule_relationship("SKIPPED") do
    :skipped
  end

  defp translate_schedule_relationship(_) do
    :scheduled
  end
end
