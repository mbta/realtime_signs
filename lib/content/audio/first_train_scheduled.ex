defmodule Content.Audio.FirstTrainScheduled do
  defstruct [:destination, :scheduled_time]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          scheduled_time: DateTime.t()
        }

  def from_messages(
        %Content.Message.EarlyAm.DestinationTrain{destination: destination},
        %Content.Message.EarlyAm.ScheduledTime{scheduled_time: scheduled_time}
      ) do
    [
      %__MODULE__{
        destination: destination,
        scheduled_time: scheduled_time
      }
    ]
  end

  def from_messages(%Content.Message.EarlyAm.DestinationScheduledTime{
        destination: destination,
        scheduled_time: scheduled_time
      }) do
    [
      %__MODULE__{
        destination: destination,
        scheduled_time: scheduled_time
      }
    ]
  end

  defimpl Content.Audio do
    @the_first "866"
    @train "864"
    @is "533"
    @scheduled_to_arrive_at "865"

    def to_params(%Content.Audio.FirstTrainScheduled{
          destination: destination,
          scheduled_time: scheduled_time
        }) do
      {:ok, destination} = PaEss.Utilities.destination_var(destination)

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
  end
end
