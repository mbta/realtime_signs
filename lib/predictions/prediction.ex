defmodule Predictions.Prediction do
  defstruct [
    stop_id: nil,
    seconds_until_arrival: nil,
    seconds_until_departure: nil,
    direction_id: nil,
    route_id: nil,
    destination_stop_id: nil
  ]

  @type t :: %__MODULE__{
    stop_id: String.t(),
    seconds_until_arrival: non_neg_integer() | nil,
    seconds_until_departure: non_neg_integer() | nil,
    direction_id: 0 | 1,
    route_id: String.t(),
    destination_stop_id: String.t()
  }
end
