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
      |> Stream.map(& &1["trip_update"])
      |> Stream.filter(
        &(relevant_rail_route?(&1["trip"]["route_id"]) and
            &1["trip"]["schedule_relationship"] != "CANCELED")
      )
      |> Stream.flat_map(&transform_stop_time_updates/1)
      |> Stream.filter(fn {update, _, _, _, _, _, _} ->
        (update["arrival"] && update["arrival"]["uncertainty"]) ||
          (update["departure"] && update["departure"]["uncertainty"])
      end)
      |> Stream.map(&prediction_from_update(&1, current_time))
      |> Enum.reject(
        &((is_nil(&1.seconds_until_arrival) and is_nil(&1.seconds_until_departure) and
             is_nil(&1.seconds_until_passthrough)) or
            (&1.seconds_until_departure && &1.seconds_until_departure < -10))
      )

    vehicles_running_revenue_trips =
      predictions
      |> Stream.filter(& &1.revenue_trip?)
      |> Stream.map(& &1.vehicle_id)
      |> MapSet.new()

    {Enum.group_by(predictions, fn prediction ->
       {prediction.stop_id, prediction.direction_id}
     end), vehicles_running_revenue_trips}
  end

  @spec transform_stop_time_updates(map()) :: [
          {map(), String.t(), String.t(), integer(), String.t(), boolean(), String.t() | nil}
        ]
  defp transform_stop_time_updates(trip_update) do
    last_stop_id =
      Enum.max_by(trip_update["stop_time_update"], fn update ->
        if update["arrival"], do: update["arrival"]["time"], else: 0
      end)
      |> Map.get("stop_id")

    vehicle_id = get_in(trip_update, ["vehicle", "id"])

    Enum.map(
      trip_update["stop_time_update"],
      &{&1, last_stop_id, trip_update["trip"]["route_id"], trip_update["trip"]["direction_id"],
       trip_update["trip"]["trip_id"], trip_update["trip"]["revenue"], vehicle_id}
    )
  end

  @spec prediction_from_update(
          {map(), String.t(), String.t(), integer(), Predictions.Prediction.trip_id(), boolean(),
           String.t() | nil},
          DateTime.t()
        ) :: Prediction.t()
  defp prediction_from_update(
         {stop_time_update, last_stop_id, route_id, direction_id, trip_id, revenue_trip?,
          vehicle_id},
         current_time
       ) do
    current_time_seconds = DateTime.to_unix(current_time)

    seconds_until_arrival =
      if stop_time_update["arrival"] &&
           sufficient_certainty?(stop_time_update["arrival"], route_id),
         do: stop_time_update["arrival"]["time"] - current_time_seconds,
         else: nil

    seconds_until_departure =
      if stop_time_update["departure"] &&
           sufficient_certainty?(stop_time_update["departure"], route_id),
         do: stop_time_update["departure"]["time"] - current_time_seconds,
         else: nil

    seconds_until_passthrough =
      if not revenue_trip?,
        do: seconds_until_arrival || seconds_until_departure,
        else: nil

    vehicle_location = Engine.Locations.for_vehicle(vehicle_id)
    vehicle_status = if not is_nil(vehicle_location), do: vehicle_location.status, else: "none"

    vehicle_locaton_stop_id =
      if not is_nil(vehicle_location), do: vehicle_location.stop_id, else: "none"

    vehicle_location_trip_id =
      if not is_nil(vehicle_location), do: vehicle_location.trip_id, else: "none"

    %Prediction{
      stop_id: stop_time_update["stop_id"],
      direction_id: direction_id,
      seconds_until_arrival: max(0, seconds_until_arrival),
      arrival_certainty: stop_time_update["arrival"]["uncertainty"],
      seconds_until_departure: seconds_until_departure,
      departure_certainty: stop_time_update["departure"]["uncertainty"],
      seconds_until_passthrough: max(0, seconds_until_passthrough),
      schedule_relationship:
        translate_schedule_relationship(stop_time_update["schedule_relationship"]),
      route_id: route_id,
      trip_id: trip_id,
      destination_stop_id: last_stop_id,
      stopped_at_predicted_stop?:
        not is_nil(vehicle_location) and vehicle_location.status == :stopped_at and
          stop_time_update["stop_id"] == vehicle_location.stop_id,
      boarding_status: stop_time_update["boarding_status"],
      revenue_trip?: revenue_trip?,
      vehicle_id: vehicle_id,
      vehicle_status: vehicle_status,
      vehicle_location_stop_id: vehicle_locaton_stop_id,
      vehicle_location_trip_id: vehicle_location_trip_id
    }
  end

  def parse_json_response("") do
    %{"entity" => []}
  end

  def parse_json_response(body) do
    Jason.decode!(body)
  end

  def relevant_rail_route?(route_id) do
    route_id in [
      "Red",
      "Blue",
      "Orange",
      "Green-B",
      "Green-C",
      "Green-D",
      "Green-E",
      "Mattapan"
    ]
  end

  @spec translate_schedule_relationship(String.t()) :: :skipped | :scheduled
  defp translate_schedule_relationship("SKIPPED") do
    :skipped
  end

  defp translate_schedule_relationship(_) do
    :scheduled
  end

  @spec sufficient_certainty?(map(), String.t()) :: boolean()
  defp sufficient_certainty?(_stop_time_event, route_id)
       when route_id in ["Mattapan", "Green-B", "Green-C", "Green-D", "Green-E"] do
    true
  end

  defp sufficient_certainty?(stop_time_event, _route_id) do
    if Application.get_env(:realtime_signs, :filter_uncertain_predictions?) do
      is_nil(stop_time_event["uncertainty"]) or stop_time_event["uncertainty"] <= 300
    else
      true
    end
  end
end
