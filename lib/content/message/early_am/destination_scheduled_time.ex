defmodule Content.Message.EarlyAm.DestinationScheduledTime do
  @enforce_keys [:destination, :scheduled_time]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          scheduled_time: DateTime.t()
        }

  defimpl Content.Message do
    def to_string(%Content.Message.EarlyAm.DestinationScheduledTime{
          destination: destination,
          scheduled_time: scheduled_time
        }) do
      "#{String.capitalize(PaEss.Utilities.destination_to_sign_string(destination))} due #{scheduled_time.hour}:#{Content.Utilities.format_minutes(scheduled_time.minute)}"
    end
  end
end
