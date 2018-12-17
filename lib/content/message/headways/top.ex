defmodule Content.Message.Headways.Top do
  require Logger
  defstruct [:headsign, :vehicle_type]

  @type t :: %__MODULE__{
          headsign: String.t(),
          vehicle_type: :bus | :trolley | :train
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Top{
          headsign: "Northbound" = headsign,
          vehicle_type: type
        }) do
      "#{signify_headsign(headsign)} #{signify_vehicle_type(type)}"
    end

    def to_string(%Content.Message.Headways.Top{
          headsign: "Southbound" = headsign,
          vehicle_type: type
        }) do
      "#{signify_headsign(headsign)} #{signify_vehicle_type(type)}"
    end

    def to_string(%Content.Message.Headways.Top{
          headsign: "Eastbound" = headsign,
          vehicle_type: type
        }) do
      "#{signify_headsign(headsign)} #{signify_vehicle_type(type)}"
    end

    def to_string(%Content.Message.Headways.Top{
          headsign: "Westbound" = headsign,
          vehicle_type: type
        }) do
      "#{signify_headsign(headsign)} #{signify_vehicle_type(type)}"
    end

    def to_string(%Content.Message.Headways.Top{headsign: headsign, vehicle_type: type}) do
      "#{signify_vehicle_type(type)} to #{signify_headsign(headsign)}"
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
