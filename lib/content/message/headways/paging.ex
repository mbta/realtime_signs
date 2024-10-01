defmodule Content.Message.Headways.Paging do
  @enforce_keys [:destination, :range]
  defstruct @enforce_keys ++ [:route]

  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          range: {non_neg_integer(), non_neg_integer()},
          route: String.t() | nil
        }

  defimpl Content.Message do
    @default_page_width 24
    def to_string(%Content.Message.Headways.Paging{
          destination: nil,
          range: range
        }) do
      [
        {"Trains every", 6},
        {format_paging_headway_range(range), 6}
      ]
    end

    def to_string(%Content.Message.Headways.Paging{
          destination: destination,
          range: range
        }) do
      [
        {destination_trains_every_string(destination), 6},
        {destination_range_string(destination, range), 6}
      ]
    end

    defp destination_trains_every_string(destination) do
      Content.Utilities.width_padded_string(
        PaEss.Utilities.destination_to_sign_string(destination),
        "trains every",
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
