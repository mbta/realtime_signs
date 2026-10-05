defmodule Signs.Config do
  defmodule Source do
    @enforce_keys [:stop_id, :direction_id, :route_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            stop_id: String.t(),
            direction_id: 0 | 1,
            route_id: String.t()
          }

    @spec parse!(map()) :: t()
    def parse!(%{"stop_id" => stop_id, "route_id" => route_id, "direction_id" => direction_id}) do
      %__MODULE__{stop_id: stop_id, route_id: route_id, direction_id: direction_id}
    end
  end

  @enforce_keys [
    :headway_group,
    :headway_destination,
    :destination,
    :terminal?,
    :announce_arriving?,
    :announce_boarding?,
    :sources
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          headway_group: String.t(),
          headway_destination: PaEss.destination() | nil,
          destination: PaEss.destination(),
          terminal?: boolean(),
          announce_arriving?: boolean(),
          announce_boarding?: boolean(),
          sources: [Source.t()]
        }

  @spec parse!(map()) :: t()
  def parse!(%{
        "headway_group" => headway_group,
        "headway_direction_name" => headway_direction_name,
        "destination" => destination,
        "terminal" => terminal?,
        "announce_arriving" => announce_arriving?,
        "announce_boarding" => announce_boarding?,
        "sources" => sources
      }) do
    %__MODULE__{
      headway_group: headway_group,
      headway_destination: PaEss.Utilities.headsign_to_destination(headway_direction_name),
      destination: PaEss.Utilities.headsign_to_destination(destination),
      terminal?: terminal?,
      announce_arriving?: announce_arriving?,
      announce_boarding?: announce_boarding?,
      sources: Enum.map(sources, &Source.parse!/1)
    }
  end
end
