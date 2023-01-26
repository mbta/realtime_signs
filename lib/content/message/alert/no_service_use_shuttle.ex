defmodule Content.Message.Alert.NoServiceUseShuttle do
  @moduledoc """
  A paging message displayed when a station is closed due to shuttles with a destination
  """

  @enforce_keys [:destination]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: Paess.destination()
        }

  defimpl Content.Message do
    @default_page_width 24
    def to_string(%Content.Message.Alert.NoServiceUseShuttle{destination: destination}) do
      [
        {Content.Utilities.width_padded_string(
           PaEss.Utilities.destination_to_sign_string(destination),
           "no service",
           @default_page_width
         ), 3},
        {Content.Utilities.width_padded_string(
           PaEss.Utilities.destination_to_sign_string(destination),
           "use shuttle",
           @default_page_width
         ), 3}
      ]
    end
  end
end
