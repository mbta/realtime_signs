defmodule Predictions.BusPrediction do
  @enforce_keys [
    :direction_id,
    :departure_time,
    :route_id,
    :stop_id,
    :headsign,
    :vehicle_id,
    :updated_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          direction_id: 0 | 1,
          departure_time: DateTime.t() | nil,
          route_id: String.t(),
          stop_id: String.t(),
          headsign: String.t(),
          vehicle_id: String.t() | nil,
          updated_at: String.t() | nil
        }
end
