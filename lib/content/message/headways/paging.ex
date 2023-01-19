defmodule Content.Message.Headways.Paging do
  defstruct [:destination, :vehicle_type, :range]

  @type vehicle_type :: :bus | :trolley | :train
  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          vehicle_type: vehicle_type(),
          range: Headway.HeadwayDisplay.headway_range() | nil
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Paging{
          destination: nil,
          vehicle_type: type,
          range: range
        }) do
      [
        {type |> signify_vehicle_type |> String.capitalize(), 3},
        {Headway.HeadwayDisplay.format_headway_range(range), 3}
      ]
    end

    def to_string(%Content.Message.Headways.Paging{
          destination: destination,
          vehicle_type: type,
          range: range
        })
        when type in [:bus] do
      [
        {"#{type |> signify_vehicle_type() |> String.capitalize()} to #{PaEss.Utilities.destination_to_sign_string(destination)}",
         3},
        {Headway.HeadwayDisplay.format_headway_range(range), 3}
      ]
    end

    def to_string(%Content.Message.Headways.Paging{
          destination: destination,
          vehicle_type: type,
          range: range
        }) do
      [
        {"#{PaEss.Utilities.destination_to_sign_string(destination)} #{signify_vehicle_type(type)}",
         3},
        {Headway.HeadwayDisplay.format_headway_range(range), 3}
      ]
    end

    @spec signify_vehicle_type(Content.Message.Headways.Top.vehicle_type()) :: String.t()
    defp signify_vehicle_type(:train) do
      "trains"
    end

    defp signify_vehicle_type(:bus) do
      "buses"
    end

    defp signify_vehicle_type(:trolley) do
      "trolleys"
    end
  end
end
