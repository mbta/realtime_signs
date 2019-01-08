defmodule Content.Message.Alert.NoService do
  @moduledoc """
  A message displayed when a station is closed due to shuttles or a suspension
  """

  defstruct mode: :train

  @type t :: %__MODULE__{
          mode: :train | nil
        }

  defimpl Content.Message do
    def to_string(msg) do
      case msg.mode do
        :train -> "No train service"
        nil -> "No service"
      end
    end
  end
end
