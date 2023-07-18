defmodule Content.Message.PlatformPredictionBottom do
  defstruct [:stop_id, :minutes]

  @type t :: %__MODULE__{
          stop_id: String.t(),
          minutes: integer() | :boarding | :arriving | :approaching | :max_time
        }

  defimpl Content.Message do
    def to_string(%Content.Message.PlatformPredictionBottom{stop_id: stop_id, minutes: minutes}) do
      if minutes == :max_time or (is_integer(minutes) and minutes > 5),
        do: "platform TBD",
        else: "on #{Content.Utilities.stop_platform_name(stop_id)} platform"
    end
  end
end
