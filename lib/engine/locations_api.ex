defmodule Engine.LocationsAPI do
  @callback for_vehicle(String.t()) :: Locations.Location.t()
  @callback for_stop(String.t()) :: [Locations.Location.t()]
end
