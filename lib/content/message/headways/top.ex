defmodule Content.Message.Headways.Top do
  require Logger
  defstruct [:headsign, :vehicle_type]

  @type t :: %__MODULE__{
    headsign: String.t(),
    vehicle_type: :bus | :trolley
  }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Top{headsign: headsign, vehicle_type: type}) do
      "#{Content.Message.Headways.Top.signify_vehicle_type(type)} to #{Content.Message.Headways.Top.signify_headsign(headsign)}"
    end
  end

  def signify_vehicle_type(:bus) do
    "Buses"
  end
  def signify_vehicle_type(:trolley) do
    "Trolleys"
  end

  def signify_headsign("South Station") do
    "South Sta"
  end
  def signify_headsign(headsign) do
    headsign
  end
end
