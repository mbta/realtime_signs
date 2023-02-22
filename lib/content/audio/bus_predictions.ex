defmodule Content.Audio.BusPredictions do
  @enforce_keys [:message]
  defstruct @enforce_keys

  defimpl Content.Audio do
    def to_params(audio) do
      audio.message
    end
  end
end
