defmodule Engine.LastTripAPI do
  @callback get_recent_departures(String.t()) :: [Map.t()]
  @callback is_last_trip?(String.t()) :: boolean()
end
