defmodule Content.Audio.BoardingButton do
  defstruct []

  defimpl Content.Audio do
    def to_tts(%Content.Audio.BoardingButton{}) do
      text =
        "Attention Passengers: To board the next train, please push the button on either side of the door."

      {text, text}
    end

    def to_logs(%Content.Audio.BoardingButton{}) do
      []
    end
  end
end
