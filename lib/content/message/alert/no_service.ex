defmodule Content.Message.Alert.NoService do
  @moduledoc """
  A message displayed when a station is closed due to shuttles or a suspension
  """

  @enforce_keys [:mode]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          mode: Signs.Utilities.SourceConfig.transit_mode()
        }

  defimpl Content.Message do
    def to_string(msg) do
      case msg.mode do
        :train -> "No train service"
        :none -> "No service"
      end
    end
  end
end
