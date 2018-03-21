defmodule Sign.Station do
  defstruct [
    :id,
    :sign_id,
    :zones,
    :display_type,
    :route_id,
    :enabled?
  ]

  @type id :: String.t
  @type t :: %__MODULE__{
    id: id,
    sign_id: String.t,
    zones: %{required(0 | 1) => atom},
    display_type: :separate | :combined | {:one_line, 0 | 1},
    route_id: String.t,
    enabled?: boolean
  }

  @doc "Returns the zone ids associated with the given station"
  def zone_ids(station) do
    Map.keys(station.zones)
  end
end
