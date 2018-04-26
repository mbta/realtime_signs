defmodule Content.Message.Headways.Bottom do
  require Logger
  defstruct [:range]

  @type t :: %__MODULE__{
    range: {integer, integer}
  }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Bottom{range: range}) do
      format_headway_range(range)
    end

    @spec format_headway_range(Headway.ScheduleHeadway.headway_range) :: String.t
    defp format_headway_range({nil, nil}), do: ""
    defp format_headway_range({x, y}) when x == y or is_nil(y), do: "Every #{x} min"
    defp format_headway_range({x, y}) when x > y, do: "Every #{y} to #{x} min"
    defp format_headway_range({x, y}), do: "Every #{x} to #{y} min"
  end
end
