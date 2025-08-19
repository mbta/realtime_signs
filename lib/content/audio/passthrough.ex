defmodule Content.Audio.Passthrough do
  @moduledoc """
  The next [line] train to [destination] does not take passengers
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
    def to_params(%Content.Audio.Passthrough{} = audio) do
      train = PaEss.Utilities.train_description_tokens(audio.destination, audio.route_id, true)

      PaEss.Utilities.audio_message(
        [:the_next] ++ train ++ [:does_not_take_passengers, :., :stand_back_message],
        :audio_visual
      )
    end

    def to_tts(%Content.Audio.Passthrough{} = audio) do
      text = tts_text(audio)
      {text, PaEss.Utilities.paginate_text(text)}
    end

    def to_logs(%Content.Audio.Passthrough{}) do
      []
    end

    defp tts_text(%Content.Audio.Passthrough{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, audio.route_id)
      "The next #{train} does not take passengers. Please stand back from the platform edge."
    end
  end
end
