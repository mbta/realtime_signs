defmodule Content.Message.EarlyAm.ScheduledTime do
  @enforce_keys [:scheduled_time]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          scheduled_time: DateTime.t()
        }

  defimpl Content.Message do
    def to_string(%Content.Message.EarlyAm.ScheduledTime{scheduled_time: scheduled_time}) do
      "due #{scheduled_time.hour}:#{Content.Utilities.format_minutes(scheduled_time.minute)}"
    end
  end
end
