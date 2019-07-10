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
        })
        when type in [:bus] do
      "#{type |> signify_vehicle_type() |> String.capitalize()} to #{signify_headsign(headsign)}"
    end

    def to_string(%Content.Message.Headways.Top{
          headsign: headsign,
          vehicle_type: type
        }) do
      "#{headsign} #{signify_vehicle_type(type)}"
    end

    @spec signify_vehicle_type(atom()) :: String.t()
    defp signify_vehicle_type(:train) do
      "trains"
    end

    defp signify_vehicle_type(:bus) do
      "buses"
    end

    defp signify_vehicle_type(:trolley) do
      "trolleys"
    end

    defp signify_headsign("South Station") do
      "South Sta"
    end

    defp signify_headsign(headsign) do
      headsign
    end
  end
end
