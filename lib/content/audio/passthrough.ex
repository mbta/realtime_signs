defmodule Content.Audio.Passthrough do
  @moduledoc """
  The next [line] train to [destination] does not take passengers
  """

  @enforce_keys [:destination]
  defstruct @enforce_keys ++ [:trip_id, :route_id]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          route_id: String.t() | nil
        }

  defimpl Content.Audio do
    def to_params(%Content.Audio.Passthrough{} = audio) do
      train = PaEss.Utilities.train_description_tokens(audio.destination, nil, true)

      PaEss.Utilities.audio_message(
        [:the_next] ++ train ++ [:does_not_take_passengers, :., :stand_back_message],
        :audio_visual
      )
    end

    def to_tts(%Content.Audio.Passthrough{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, nil)
      train_visual = PaEss.Utilities.train_description(audio.destination, nil, :visual)

      {"The next, #{train}; does not take passengers. Please stand back from the platform edge.",
       "The next #{train_visual} does not take passengers. Please stand back from the platform edge."}
    end

    def to_logs(%Content.Audio.Passthrough{}) do
      []
    end
  end
end
