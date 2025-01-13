defmodule Content.Message.PlatformPredictionBottom do
  defstruct [:stop_id, :minutes, :destination]

  @type t :: %__MODULE__{
          stop_id: String.t(),
          minutes: integer() | :boarding | :arriving,
          destination: PaEss.destination()
        }

  defimpl Content.Message do
    def to_string(%Content.Message.PlatformPredictionBottom{stop_id: stop_id, minutes: minutes}) do
      if is_integer(minutes) and minutes > 5,
        do: "platform TBD",
        else: "on #{Content.Utilities.stop_platform_name(stop_id)} platform"
    end
  end
end
