defmodule Predictions.Prediction do
  defstruct [
    stop_id: nil,
    seconds_until_arrival: nil,
    direction_id: nil,
    route_id: nil,
    headsign: nil
  ]

  @type t :: %__MODULE__{
    stop_id: String.t(),
    seconds_until_arrival: non_neg_integer(),
    direction_id: 0 | 1,
    route_id: String.t(),
    headsign: String.t()
  }
end
