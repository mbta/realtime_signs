defmodule Content.Audio.FirstTrainScheduled do
  defstruct [:destination, :scheduled_time]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          scheduled_time: DateTime.t()
        }

  defimpl Content.Audio do
    def to_tts(%Content.Audio.FirstTrainScheduled{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, nil)
      time = Content.Utilities.render_datetime_as_time(audio.scheduled_time)
      {["The first, #{train}", "departs at #{time}"] |> PaEss.Utilities.tts_sentence(), nil}
    end

    def to_logs(%Content.Audio.FirstTrainScheduled{}) do
      []
    end
  end
end
