defmodule Content.Audio.BoardingButton do
  alias PaEss.Utilities
  defstruct []

  defimpl Content.Audio do
    @boarding_button_message "869"

    def to_params(_audio) do
      Utilities.take_message([@boarding_button_message], :audio_visual)
    end
  end
end
