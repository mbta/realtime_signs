defmodule Content.Message.Alert.NoService do
  @moduledoc """
  A message displayed when a station is closed due to shuttles or a suspension
  """

  defstruct [:route, :destination]

  @type t :: %__MODULE__{
          route: String.t() | nil,
          destination: PaEss.destination() | nil
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Alert.NoService{destination: nil, route: route}) do
      service = if(route, do: "#{route} Line", else: "train service")
      "No #{service}"
    end

    def to_string(%Content.Message.Alert.NoService{destination: destination}) do
      "No #{PaEss.Utilities.destination_to_sign_string(destination)} svc"
    end
  end
end
