defmodule Content.Audio.FirstTrainScheduled do
  defstruct [:destination, :scheduled_time]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          scheduled_time: DateTime.t()
        }

  defimpl Content.Audio do
    def to_params(%Content.Audio.FirstTrainScheduled{
          destination: destination,
          scheduled_time: scheduled_time
        }) do
      PaEss.Utilities.audio_message([
        :the_first,
        destination,
        :train,
        :departs_at,
        {:hour, scheduled_time.hour},
        {:minute, scheduled_time.minute}
      ])
    end

    def to_tts(%Content.Audio.FirstTrainScheduled{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, nil)
      time = Content.Utilities.render_datetime_as_time(audio.scheduled_time)
      {"The first #{train} departs at #{time}", nil}
    end

    def to_logs(%Content.Audio.FirstTrainScheduled{}) do
      []
    end
  end
end
