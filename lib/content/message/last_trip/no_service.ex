defmodule Content.Message.LastTrip.NoService do
  @enforce_keys [:destination]
  defstruct @enforce_keys ++ [:route, variant: :long]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route: String.t() | nil,
          variant: :long | :short
        }

  defimpl Content.Message do
    def to_string(%Content.Message.LastTrip.NoService{destination: destination, variant: :long}) do
      Content.Utilities.width_padded_string(
        PaEss.Utilities.destination_to_sign_string(destination),
        "Svc ended",
        24
      )
    end

    def to_string(%Content.Message.LastTrip.NoService{destination: destination, variant: :short}) do
      Content.Utilities.width_padded_string(
        PaEss.Utilities.destination_to_sign_string(destination),
        "No Svc",
        18
      )
    end
  end
end
