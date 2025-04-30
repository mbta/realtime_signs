defmodule Predictions.Predictions do
  alias Predictions.Prediction
  require Logger

  @excluded_prediction_types []

  @spec get_all(map(), DateTime.t()) ::
          {%{
             optional({String.t(), integer()}) => [Prediction.t()]
           }, MapSet.t(String.t())}
  def get_all(feed_message, current_time) do
    predictions =
      feed_message["entity"]
      |> Stream.map(& &1["trip_update"])
      |> Stream.filter(&valid_trip_update?/1)
      |> Stream.flat_map(&trip_update_to_predictions(&1, current_time))

    vehicles_running_revenue_trips =
      predictions
      |> Stream.filter(& &1.revenue_trip?)
      |> Stream.map(& &1.vehicle_id)
      |> MapSet.new()

    {Enum.group_by(predictions, fn prediction ->
       {prediction.stop_id, prediction.direction_id}
     end), vehicles_running_revenue_trips}
  end

  defp valid_trip_update?(trip_update) do
    relevant_rail_route?(trip_update["trip"]["route_id"]) and
      trip_update["trip"]["schedule_relationship"] != "CANCELED"
  end

  @spec trip_update_to_predictions(map(), DateTime.t()) :: [Prediction.t()]
  defp trip_update_to_predictions(trip_update, current_time) do
    vehicle_id = trip_update["vehicle"]["id"]

    for stop_time_update <- trip_update["stop_time_update"],
        is_valid_prediction?(stop_time_update),
        prediction =
          build_prediction(
            stop_time_update,
            get_destination_stop_id(trip_update),
            vehicle_id,
            RealtimeSigns.location_engine().for_vehicle(vehicle_id),
            trip_update["trip"]["route_id"],
            trip_update["trip"]["direction_id"],
            trip_update["trip"]["trip_id"],
            trip_update["trip"]["revenue"],
            get_prediction_type(trip_update["update_type"]),
            DateTime.to_unix(current_time)
          ),
        not has_departed?(prediction),
        not is_excluded_prediction_type?(prediction),
        do: prediction
  end

  @spec build_prediction(
          map(),
          String.t(),
          String.t(),
          Locations.Location.t(),
          String.t(),
          integer(),
          Predictions.Prediction.trip_id(),
          boolean(),
          atom(),
          integer()
        ) :: Prediction.t()
  defp build_prediction(
         stop_time_update,
         destination_stop_id,
         vehicle_id,
         vehicle_location,
         route_id,
         direction_id,
         trip_id,
         revenue_trip?,
         prediction_type,
         current_time_seconds
       ) do
    schedule_relationship =
      translate_schedule_relationship(stop_time_update["schedule_relationship"])

    seconds_until_arrival =
      stop_time_update["arrival"] && stop_time_update["arrival"]["time"] - current_time_seconds

    seconds_until_departure =
      stop_time_update["departure"] &&
        stop_time_update["departure"]["time"] - current_time_seconds

    seconds_until_passthrough =
      stop_time_update["passthrough_time"] &&
        stop_time_update["passthrough_time"] - current_time_seconds

    %Prediction{
      stop_id: stop_time_update["stop_id"],
      direction_id: direction_id,
      seconds_until_arrival: max(0, seconds_until_arrival),
      seconds_until_departure: seconds_until_departure,
      seconds_until_passthrough: max(0, seconds_until_passthrough),
      schedule_relationship: schedule_relationship,
      route_id: route_id,
      trip_id: trip_id,
      destination_stop_id: destination_stop_id,
      stopped_at_predicted_stop?:
        not is_nil(vehicle_location) and vehicle_location.status == :stopped_at and
          stop_time_update["stop_id"] == vehicle_location.stop_id,
      boarding_status: stop_time_update["boarding_status"],
      revenue_trip?: revenue_trip?,
      vehicle_id: vehicle_id,
      multi_carriage_details: if(vehicle_location, do: vehicle_location.multi_carriage_details),
      type: prediction_type
    }
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

  defp get_destination_stop_id(trip_update) do
    Enum.max_by(trip_update["stop_time_update"], fn update ->
      if update["arrival"], do: update["arrival"]["time"], else: 0
    end)
    |> Map.get("stop_id")
  end

  @spec get_prediction_type(String.t()) :: Prediction.prediction_type()
  defp get_prediction_type(update_type) do
    case update_type do
      "mid_trip" -> :mid_trip
      "at_terminal" -> :terminal
      "reverse_trip" -> :reverse
      _ -> nil
    end
  end

  defp is_valid_prediction?(stop_time_update) do
    not (is_nil(stop_time_update["arrival"]) and is_nil(stop_time_update["departure"]) and
           is_nil(stop_time_update["passthrough_time"]))
  end

  @spec is_excluded_prediction_type?(Prediction.t()) :: boolean()
  defp is_excluded_prediction_type?(prediction)
       when prediction.route_id in ["Mattapan", "Green-B", "Green-C", "Green-D", "Green-E"],
       do: false

  defp is_excluded_prediction_type?(prediction) do
    prediction.type in @excluded_prediction_types
  end

  @spec has_departed?(Prediction.t()) :: boolean()
  defp has_departed?(prediction) do
    not is_nil(prediction.seconds_until_departure) and prediction.seconds_until_departure < 0 and
      not prediction.stopped_at_predicted_stop?
  end
end
