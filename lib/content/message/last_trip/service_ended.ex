defmodule Content.Message.LastTrip.ServiceEnded do
  @moduledoc """
  A message displayed when a station is closed
  """
  @enforce_keys []
  defstruct @enforce_keys ++ [:destination]

  @type t :: %__MODULE__{
          destination: PaEss.destination()
        }

  defimpl Content.Message do
    def to_string(%Content.Message.LastTrip.ServiceEnded{destination: nil}) do
      "Service ended for night"
    end

    def to_string(%Content.Message.LastTrip.ServiceEnded{destination: destination}) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)
      "No #{headsign} trains"
    end
  end
end
