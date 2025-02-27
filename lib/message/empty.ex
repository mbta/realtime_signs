defmodule Message.Empty do
  defstruct []

  @type t :: %__MODULE__{}

  defimpl Message do
    def to_single_line(%Message.Empty{}, _) do
      ""
    end

    def to_full_page(%Message.Empty{}) do
      {"", ""}
    end

    def to_multi_line(%Message.Empty{} = message), do: to_full_page(message)

    def to_audio(%Message.Empty{}, _multiple?) do
      []
    end
  end
end
