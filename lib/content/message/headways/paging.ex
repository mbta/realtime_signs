defmodule Content.Message.Headways.Paging do
  defstruct [:destination, :vehicle_type, :range]

  @type vehicle_type :: :bus | :trolley | :train
  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          vehicle_type: vehicle_type(),
          range: Headway.HeadwayDisplay.headway_range() | nil
        }

  defimpl Content.Message do
    @default_page_width 24
    def to_string(%Content.Message.Headways.Paging{
          destination: nil,
          vehicle_type: type,
          range: range
        }) do
      [
        {"#{signify_vehicle_type(type) |> String.capitalize()} every", 3},
        {format_paging_headway_range(range), 3}
      ]
    end

    def to_string(%Content.Message.Headways.Paging{
          destination: destination,
          vehicle_type: vehicle_type,
          range: range
        }) do
      [
        {destination_vehicle_string(destination, vehicle_type), 3},
        {destination_range_string(destination, range), 3}
      ]
    end

    @spec signify_vehicle_type(Content.Message.Headways.Paging.vehicle_type()) :: String.t()
    defp signify_vehicle_type(:train) do
      "trains"
    end

    defp signify_vehicle_type(:bus) do
      "buses"
    end

    defp signify_vehicle_type(:trolley) do
      "trolleys"
    end

    defp destination_vehicle_string(destination, vehicle_type) do
      Content.Utilities.width_padded_string(
        PaEss.Utilities.destination_to_sign_string(destination),
        "#{signify_vehicle_type(vehicle_type)} every",
        @default_page_width
      )
    end

    defp destination_range_string(destination, range) do
      Content.Utilities.width_padded_string(
        PaEss.Utilities.destination_to_sign_string(destination),
        format_paging_headway_range(range),
        @default_page_width
      )
    end

    defp format_paging_headway_range({x, y}), do: "#{x} to #{y} min"
  end
end
