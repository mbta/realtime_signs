defmodule Content.Audio.StoppedTrain do
  @moduledoc """
  The next train to [destination] is stopped [n] [stop/stops] away.
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:destination, :route_id, :stops_away]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route_id: String.t(),
          stops_away: non_neg_integer()
        }

  @spec from_message(Content.Message.t()) :: [t()]
  def from_message(%Content.Message.StoppedTrain{
        destination: destination,
        stops_away: stops_away,
        prediction: prediction
      })
      when stops_away > 0 do
    [%__MODULE__{destination: destination, route_id: prediction.route_id, stops_away: stops_away}]
  end

  def from_message(%Content.Message.StoppedTrain{stops_away: 0}) do
    []
  end

  def from_message(message) do
    Logger.error("message_to_audio_error Audio.StoppedTrain #{inspect(message)}")
    []
  end

  defimpl Content.Audio do
    def to_params(audio) do
      stops_away = if(audio.stops_away == 1, do: :stop_away, else: :stops_away)

      PaEss.Utilities.audio_message(
        [:the_next] ++
          PaEss.Utilities.train_description_tokens(audio.destination, audio.route_id) ++
          [:is, :stopped, {:number, audio.stops_away}, stops_away]
      )
    end

    def to_tts(%Content.Audio.StoppedTrain{} = audio) do
      {tts_text(audio), nil}
    end

    def to_logs(%Content.Audio.StoppedTrain{}) do
      []
    end

    defp tts_text(%Content.Audio.StoppedTrain{} = audio) do
      train = Utilities.train_description(audio.destination, audio.route_id)
      stop_or_stops = if audio.stops_away == 1, do: "stop", else: "stops"
      "The next #{train} is stopped #{audio.stops_away} #{stop_or_stops} away"
    end
  end
end
