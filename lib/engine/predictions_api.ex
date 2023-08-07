defmodule Engine.PredictionsAPI do
  @callback for_stop(String.t(), 0 | 1) :: [Predictions.Prediction.t()]
end
