defmodule Content.Audio.Passthrough do
  @moduledoc """
  The next [line] train to [destination] does not take customers
  """

  require Logger

  @enforce_keys [:destination]
  defstruct @enforce_keys ++ [:trip_id, :route_id]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          route_id: String.t() | nil
        }

  defimpl Content.Audio do
    def to_params(%Content.Audio.Passthrough{route_id: route_id} = audio)
        when route_id in ["Mattapan", "Green-B", "Green-C", "Green-D", "Green-E"] do
      handle_unknown_destination(audio)
    end

    def to_params(audio) do
      PaEss.Utilities.audio_message(
        [{:passthrough, audio.destination, audio.route_id}],
        :audio_visual
      )
    end

    def to_tts(%Content.Audio.Passthrough{} = audio) do
      text = tts_text(audio)
      {text, PaEss.Utilities.paginate_text(text)}
    end

    def to_logs(%Content.Audio.Passthrough{trip_id: trip_id}) do
      # trip_id for debugging RTR/Contentrate differences
      [trip_id: trip_id]
    end

    defp tts_text(%Content.Audio.Passthrough{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, audio.route_id)
      "The next #{train} does not take customers. Please stand back from the yellow line."
    end

    @spec handle_unknown_destination(Content.Audio.Passthrough.t()) :: nil
    defp handle_unknown_destination(audio) do
      Logger.info(
        "unknown_passthrough_audio: destination=#{audio.destination} route_id=#{audio.route_id}"
      )

      nil
    end
  end
end
