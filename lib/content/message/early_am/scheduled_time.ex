defmodule Content.Message.EarlyAm.ScheduledTime do
  @enforce_keys [:scheduled_time]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          scheduled_time: DateTime.t()
        }

  defimpl Content.Message do
    def to_string(%Content.Message.EarlyAm.ScheduledTime{scheduled_time: scheduled_time}) do
      "due #{Content.Utilities.render_datetime_as_time(scheduled_time)}"
    end
  end
end
