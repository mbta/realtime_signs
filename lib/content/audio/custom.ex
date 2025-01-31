defmodule Content.Audio.Custom do
  @moduledoc """
  Reads custom text from the PIOs
  """

  require Logger

  @enforce_keys [:message]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          message: String.t()
        }

  defimpl Content.Audio do
    def to_params(%Content.Audio.Custom{message: message}) do
      {:ad_hoc, {message, :audio}}
    end

    def to_tts(%Content.Audio.Custom{} = audio) do
      {audio.message, nil}
    end

    def to_logs(%Content.Audio.Custom{}) do
      []
    end
  end
end
