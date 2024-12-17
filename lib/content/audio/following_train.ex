defmodule Content.Audio.FollowingTrain do
  @moduledoc """
  The following train to [destination] arrives in [n] minutes.
  """

  @enforce_keys [:destination, :route_id, :verb, :minutes]
  defstruct @enforce_keys

  @type verb :: :arrives | :departs

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route_id: String.t(),
          verb: verb(),
          minutes: integer()
        }

  require Logger

  @spec from_predictions_message(Content.Message.Predictions.t()) :: [
          Content.Audio.FollowingTrain.t()
        ]
  def from_predictions_message(%Content.Message.Predictions{
        minutes: n,
        destination: destination,
        prediction: prediction,
        terminal?: terminal
      })
      when is_integer(n) do
    [
      %__MODULE__{
        destination: destination,
        route_id: prediction.route_id,
        minutes: n,
        verb: arrives_or_departs(terminal)
      }
    ]
  end

  def from_predictions_message(_msg) do
    []
  end

  @spec arrives_or_departs(boolean) :: :arrives | :departs
  defp arrives_or_departs(true), do: :departs
  defp arrives_or_departs(false), do: :arrives

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(audio) do
      min_or_mins = if(audio.minutes == 1, do: :minute, else: :minutes)

      Utilities.audio_message(
        [:the_following] ++
          Utilities.train_description_tokens(audio.destination, audio.route_id) ++
          [audio.verb, :in, {:number, audio.minutes}, min_or_mins]
      )
    end

    def to_tts(%Content.Audio.FollowingTrain{} = audio) do
      {tts_text(audio), nil}
    end

    def to_logs(%Content.Audio.FollowingTrain{}) do
      []
    end

    defp tts_text(%Content.Audio.FollowingTrain{} = audio) do
      train = Utilities.train_description(audio.destination, audio.route_id)
      arrives_or_departs = if audio.verb == :arrives, do: "arrives", else: "departs"
      min_or_mins = if audio.minutes == 1, do: "minute", else: "minutes"
      "The following #{train} #{arrives_or_departs} in #{audio.minutes} #{min_or_mins}"
    end
  end
end
