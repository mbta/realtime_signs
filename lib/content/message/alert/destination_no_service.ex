defmodule Content.Message.Alert.DestinationNoService do
  @moduledoc """
  A message displayed when a station is closed while including a destination
  """

  @enforce_keys [:destination]
  defstruct @enforce_keys ++ [:route, variant: :long]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route: String.t() | nil,
          variant: :long | :short
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Alert.DestinationNoService{
          destination: destination,
          variant: :long
        }) do
      Content.Utilities.width_padded_string(
        PaEss.Utilities.destination_to_sign_string(destination),
        "no service",
        24
      )
    end

    def to_string(%Content.Message.Alert.DestinationNoService{
          destination: destination,
          variant: :short
        }) do
      Content.Utilities.width_padded_string(
        PaEss.Utilities.destination_to_sign_string(destination),
        "no svc",
        18
      )
    end
  end
end
