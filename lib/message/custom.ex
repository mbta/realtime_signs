defmodule Message.Custom do
  @enforce_keys [:top, :bottom]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          top: String.t(),
          bottom: String.t()
        }

  defimpl Message do
    def to_single_line(%Message.Custom{}, _) do
      raise "Cannot render custom message on one line"
    end

    def to_full_page(%Message.Custom{top: top, bottom: bottom}) do
      {PaEss.Utilities.validate_custom_string(top, :top),
       PaEss.Utilities.validate_custom_string(bottom, :bottom)}
    end

    def to_multi_line(%Message.Custom{} = message), do: to_full_page(message)

    def to_audio(%Message.Custom{top: top, bottom: bottom}, _multiple?) do
      [%Content.Audio.Custom{message: PaEss.Utilities.custom_tts_text(top, bottom)}]
    end
  end
end
