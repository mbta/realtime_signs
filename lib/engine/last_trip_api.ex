defmodule Engine.LastTripAPI do
  @callback get_recent_departures(String.t()) :: [Map.t()]
  @callback get_last_trips(String.t()) :: [Map.t()]
end
