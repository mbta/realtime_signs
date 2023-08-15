defmodule Engine.LocationsAPI do
  @callback for_vehicle(String.t()) :: [Predictions.Prediction.t()]
end
