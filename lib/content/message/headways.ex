defmodule Content.Message.Headways do
  defimpl Content.Message do
    @width 18

  defimpl Content.Message do
    require Logger

    def to_string(%{headsign: headsign, range: {max_headway, min_headway}}) do
      vehicle_type = "Buses"
      "#{vehicle_type} to #{headsign}"
    end

    @spec format_headway_range(headway_range) :: String.t
    defp format_headway_range({nil, nil}), do: ""
    defp format_headway_range({x, y}) when x == y or is_nil(y), do: "Every #{x} min"
    defp format_headway_range({x, y}) when x > y, do: "Every #{y} to #{x} min"
    defp format_headway_range({x, y}), do: "Every #{x} to #{y} min"

    @spec max_headway(headway_range) :: non_neg_integer | nil
    defp max_headway({nil, nil}), do: nil
    defp max_headway({nil, y}), do: y
    defp max_headway({x, nil}), do: x
    defp max_headway({x, y}), do: max(x, y)
    end
  end
end
