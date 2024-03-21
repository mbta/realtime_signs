defmodule Content.Audio.BoardingButton do
  alias PaEss.Utilities
  defstruct []

  defimpl Content.Audio do
    @boarding_button_message "869"

    def to_params(_audio) do
      Utilities.take_message([@boarding_button_message], :audio_visual)
    end

    def to_tts(%Content.Audio.BoardingButton{}) do
      "Attention Passengers: To board the next train, please push the button on either side of the door."
    end
  end
end
