defmodule Content.Message.Headways.Bottom do
  require Logger
  defstruct [:range, :last_departure]

  @type t :: %__MODULE__{
          range: Headway.ScheduleHeadway.headway_range(),
          last_departure: DateTime.t() | nil
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Bottom{
          range: {:first_departure, range, _first_departure}
        }) do
      Headway.ScheduleHeadway.format_headway_range(range)
    end

    def to_string(%Content.Message.Headways.Bottom{range: range, last_departure: last_departure}) do
      current_time = Timex.now()

      case last_departure do
        nil ->
          Headway.ScheduleHeadway.format_headway_range(range)

        _ ->
          [
            {Headway.ScheduleHeadway.format_headway_range(range), 3},
            {Headway.ScheduleHeadway.format_last_departure(last_departure, current_time), 3}
          ]
      end
    end
  end
end
