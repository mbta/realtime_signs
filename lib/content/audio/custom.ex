defmodule Content.Audio.Custom do
  @moduledoc """
  Reads custom text from the PIOs
  """

  @enforce_keys [:top, :bottom, :audio_text]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          top: String.t(),
          bottom: String.t(),
          audio_text: String.t()
        }

  defimpl Content.Audio do
    def to_tts(%Content.Audio.Custom{audio_text: audio_text}) do
      {audio_text, nil}
    end

    def to_logs(%Content.Audio.Custom{}) do
      []
    end
  end
end
