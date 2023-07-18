defmodule Content.Message.EarlyAm.DestinationTrain do
  @enforce_keys [:destination]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination()
        }

  defimpl Content.Message do
    def to_string(%Content.Message.EarlyAm.DestinationTrain{destination: destination}) do
      "#{String.capitalize(PaEss.Utilities.destination_to_sign_string(destination))} train"
    end
  end
end
