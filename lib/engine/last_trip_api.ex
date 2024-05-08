defmodule Engine.LastTripAPI do
  @callback get_recent_departures(String.t()) :: map()
  @callback is_last_trip?(String.t()) :: boolean()
end
