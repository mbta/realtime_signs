defmodule Message.Custom do
  @enforce_keys [:top, :bottom]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          top: String.t(),
          bottom: String.t()
        }

  defimpl Message do
    def to_single_line(%Message.Custom{}) do
      raise "Cannot render custom message on one line"
    end

    def to_full_page(%Message.Custom{} = message) do
      {Content.Message.Custom.new(message.top, :top),
       Content.Message.Custom.new(message.bottom, :bottom)}
    end

    def to_multi_line(%Message.Custom{} = message), do: to_full_page(message)
  end
end
