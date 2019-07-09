defmodule Content.Message.Headways.Top do
  require Logger
  defstruct [:headsign, :vehicle_type]

  @type vehicle_type :: :bus | :trolley | :train
  @type t :: %__MODULE__{
          headsign: String.t(),
          vehicle_type: vehicle_type
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Top{
          headsign: headsign,
          vehicle_type: type
        }) do
      "#{headsign} #{signify_vehicle_type(type)}"
    end

    defp signify_vehicle_type(:train) do
      "Trains"
    end

    defp signify_vehicle_type(:bus) do
      "Buses"
    end

    defp signify_vehicle_type(:trolley) do
      "Trolleys"
    end

    defp signify_headsign("South Station") do
      "South Sta"
    end

    defp signify_headsign(headsign) do
      headsign
    end
  end
end
