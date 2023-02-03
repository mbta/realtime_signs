defmodule Content.Message.BusPredictions do
  @enforce_keys [:message]
  defstruct @enforce_keys

  defimpl Content.Message do
    def to_string(message) do
      message.message
    end
  end
end
