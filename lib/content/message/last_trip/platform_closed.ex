defmodule Content.Message.LastTrip.PlatformClosed do
  @moduledoc """
  A message displayed when a station is closed
  """
  @enforce_keys [:destination]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination()
        }

  defimpl Content.Message do
    def to_string(%Content.Message.LastTrip.PlatformClosed{}) do
      "Platform closed"
    end
  end
end
