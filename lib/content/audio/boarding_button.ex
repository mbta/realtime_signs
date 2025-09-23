defmodule Content.Audio.BoardingButton do
  alias PaEss.Utilities
  defstruct []

  defimpl Content.Audio do
    def to_params(_audio) do
      Utilities.audio_message([:boarding_button_message], :audio_visual)
    end

    def to_tts(%Content.Audio.BoardingButton{}, max_text_length) do
      text =
        "Attention Passengers: To board the next train, please push the button on either side of the door."

      {text, PaEss.Utilities.paginate_text(text, max_text_length)}
    end

    def to_logs(%Content.Audio.BoardingButton{}) do
      []
    end
  end
end
