defmodule Message.Empty do
  defstruct []

  @type t :: %__MODULE__{}

  defimpl Message do
    def to_single_line(%Message.Empty{}) do
      %Content.Message.Empty{}
    end

    def to_full_page(%Message.Empty{}) do
      {%Content.Message.Empty{}, %Content.Message.Empty{}}
    end

    def to_multi_line(%Message.Empty{} = message), do: to_full_page(message)
  end
end
