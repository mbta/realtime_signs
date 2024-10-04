defmodule Content.Message.Alert.DestinationNoService do
  @moduledoc """
  A message displayed when a station is closed while including a destination
  """

  @enforce_keys [:destination]
  defstruct @enforce_keys ++ [:route]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route: String.t() | nil
        }

  defimpl Content.Message do
    @default_page_width 24
    def to_string(%Content.Message.Alert.DestinationNoService{destination: destination}) do
      Content.Utilities.width_padded_string(
        PaEss.Utilities.destination_to_sign_string(destination),
        "no service",
        @default_page_width
      )
    end
  end
end
