defmodule Message.Custom do
  @enforce_keys [:top, :bottom]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          top: String.t(),
          bottom: String.t()
        }

  defimpl Message do
    @invalid_character ~r/[^a-zA-Z0-9,\/!@': ]/

    def to_single_line(%Message.Custom{}, _) do
      raise "Cannot render custom message on one line"
    end

    def to_full_page(%Message.Custom{top: top, bottom: bottom}) do
      {validate(top, :top), validate(bottom, :bottom)}
    end

    def to_multi_line(%Message.Custom{} = message), do: to_full_page(message)

    def to_audio(%Message.Custom{top: top, bottom: bottom}, _multiple?) do
      [
        %Content.Audio.Custom{
          message: String.trim("#{validate(top, :top)} #{validate(bottom, :bottom)}")
        }
      ]
    end

    defp validate(string, line) do
      string
      |> String.replace(@invalid_character, "")
      |> String.slice(0, if(line == :top, do: 18, else: 24))
    end
  end
end
