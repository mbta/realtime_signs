defmodule Engine.PredictionsAPI do
  @callback for_stop(String.t(), 0 | 1) :: [Predictions.Prediction.t()]
  @callback revenue_vehicles() :: MapSet.t()
end
