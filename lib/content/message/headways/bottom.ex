defmodule Content.Message.Headways.Bottom do
  require Logger
  defstruct [:range, :prev_departure_mins]

  @type t :: %__MODULE__{
          range: Headway.ScheduleHeadway.headway_range(),
          prev_departure_mins: integer() | nil
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Bottom{
          range: {:first_departure, range, _first_departure}
        }) do
      Headway.ScheduleHeadway.format_headway_range(range)
    end

    def to_string(%Content.Message.Headways.Bottom{} = bottom) do
      Headway.ScheduleHeadway.format_bottom(bottom)
    end
  end
end
