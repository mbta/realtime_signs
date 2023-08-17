defmodule Engine.LocationsAPI do
  @callback for_vehicle(String.t()) :: Locations.Location.t()
end
