defmodule Content.Message.Custom do
  @moduledoc """
  Custom text entered by a PIO to override other predictions or alert messages
  """

  @enforce_keys [:message]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          message: String.t()
        }

  @spec new(String.t()) :: t()
  def new(message) do
    %__MODULE__{
      message: message
    }
  end

  defimpl Content.Message do
    def to_string(message) do
      message.message
    end
  end
end
