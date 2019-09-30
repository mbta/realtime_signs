defmodule Predictions.Prediction do
  defstruct stop_id: nil,
            seconds_until_arrival: nil,
            seconds_until_departure: nil,
            seconds_until_passthrough: nil,
            direction_id: nil,
            schedule_relationship: nil,
            route_id: nil,
            trip_id: nil,
            destination_stop_id: nil,
            stopped?: false,
            stops_away: 0,
            boarding_status: nil,
            new_cars?: false,
            revenue_trip?: true,
            vehicle_id: nil

  @type trip_id :: String.t()

  @type t :: %__MODULE__{
          stop_id: String.t(),
          seconds_until_arrival: non_neg_integer() | nil,
          seconds_until_departure: non_neg_integer() | nil,
          seconds_until_passthrough: non_neg_integer() | nil,
          direction_id: 0 | 1,
          schedule_relationship: :scheduled | :skipped | nil,
          route_id: String.t(),
          trip_id: trip_id() | nil,
          destination_stop_id: String.t(),
          stopped?: boolean(),
          stops_away: integer(),
          boarding_status: String.t() | nil,
          new_cars?: boolean(),
          revenue_trip?: boolean(),
          vehicle_id: String.t() | nil
        }
end
