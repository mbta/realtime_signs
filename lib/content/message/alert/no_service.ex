defmodule Content.Message.Alert.NoService do
  @moduledoc """
  A message displayed when a station is closed due to shuttles or a suspension
  """

  defstruct [:route]

  @type t :: %__MODULE__{
          route: String.t() | nil
        }

  defimpl Content.Message do
    def to_string(%Content.Message.Alert.NoService{route: route}) do
      service = if(route, do: "#{route} Line", else: "train service")
      "No #{service}"
    end
  end
end
