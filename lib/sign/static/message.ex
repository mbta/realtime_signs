defmodule Sign.Static.Message do
  alias Sign.Stations

  defstruct station_id: nil,
    sign_id: nil,
    direction: 0,
    top_text: "",
    bottom_text: ""

  @type t :: %__MODULE__{
    station_id: String.t,
    sign_id: String.t,
    direction: 0 | 1,
    top_text: String.t,
    bottom_text: String.t
  }

  def from_map({gtfs_id, data}) do
    %__MODULE__{
      station_id: gtfs_id,
      sign_id: gtfs_id |> Stations.Live.for_gtfs_id() |> Map.get(:sign_id),
      direction: Map.get(data, "direction"),
      top_text: Map.get(data, "top_text", ""),
      bottom_text: Map.get(data, "bottom_text", "")
    }
  end
end
