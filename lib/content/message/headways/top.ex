defmodule Content.Message.Headways.Top do
  require Logger
  defstruct [:headsign, :vehicle_type]

  @type t :: %__MODULE__{
    headsign: String.t(),
    vehicle_type: String.t()
  }

  defimpl Content.Message, for: Content.Message.Headways.Top do
    def to_string(%Content.Message.Headways.Top{headsign: headsign, vehicle_type: type}) do
      "#{type} to #{headsign}"
    end
  end
end
