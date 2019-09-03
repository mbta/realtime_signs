defmodule Content.Message.Headways.Bottom do
  require Logger
  defstruct [:range, :last_departure]

  @type t :: %__MODULE__{
          range: Headway.ScheduleHeadway.headway_range(),
          last_departure: integer() | nil
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Bottom{
          range: {:first_departure, range, _first_departure}
        }) do
      Headway.ScheduleHeadway.format_headway_range(range)
    end

    def to_string(
          %Content.Message.Headways.Bottom{range: _range, last_departure: _last_departure} =
            bottom
        ) do
      Headway.ScheduleHeadway.format_bottom(bottom)
    end
  end
end
