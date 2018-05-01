defmodule Content.Message.Headways.Bottom do
  require Logger
  defstruct [:range]

  @type t :: %__MODULE__{
    range: ScheduleHeadway.headway_range()
  }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Bottom{range: range}) do
      Headway.ScheduleHeadway.format_headway_range(range)
    end
  end
end
