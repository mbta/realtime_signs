defmodule Message.FirstTrain do
  @enforce_keys [:destination, :scheduled]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          scheduled: DateTime.t()
        }

  defimpl Message do
    def to_single_line(%Message.FirstTrain{destination: destination, scheduled: scheduled}, :long) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)
      "#{headsign} due #{Content.Utilities.render_datetime_as_time(scheduled)}"
    end

    def to_single_line(%Message.FirstTrain{}, :short), do: nil

    def to_full_page(%Message.FirstTrain{destination: destination, scheduled: scheduled}) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)
      {"#{headsign} train", "due #{Content.Utilities.render_datetime_as_time(scheduled)}"}
    end

    def to_multi_line(%Message.FirstTrain{} = message), do: to_full_page(message)

    def to_audio(%Message.FirstTrain{} = message, _multiple?) do
      [
        %Content.Audio.FirstTrainScheduled{
          destination: message.destination,
          scheduled_time: message.scheduled
        }
      ]
    end
  end
end
