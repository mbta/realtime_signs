defmodule Content.Audio.FirstTrainScheduled do
  defstruct [:destination, :scheduled_time]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          scheduled_time: DateTime.t()
        }

  defimpl Content.Audio do
    @the_first "866"
    @train "864"
    @is "533"
    @scheduled_to_arrive_at "865"

    def to_params(%Content.Audio.FirstTrainScheduled{
          destination: destination,
          scheduled_time: scheduled_time
        }) do
      destination = PaEss.Utilities.destination_var(destination)

      vars = [
        @the_first,
        destination,
        @train,
        @is,
        @scheduled_to_arrive_at,
        PaEss.Utilities.time_hour_var(scheduled_time.hour),
        PaEss.Utilities.time_minutes_var(scheduled_time.minute)
      ]

      PaEss.Utilities.take_message(vars, :audio)
    end

    def to_tts(%Content.Audio.FirstTrainScheduled{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, nil)
      time = Content.Utilities.render_datetime_as_time(audio.scheduled_time)
      {"The first #{train} is scheduled to arrive at #{time}", nil}
    end

    def to_logs(%Content.Audio.FirstTrainScheduled{}) do
      []
    end
  end
end
