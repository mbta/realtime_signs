defmodule Content.Message.Alert.NoService do
  @moduledoc """
  A message displayed when a station is closed due to shuttles or a suspension
  """

  @enforce_keys [:routes]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  defimpl Content.Message do
    def to_string(%Content.Message.Alert.NoService{routes: routes}) do
      "No #{PaEss.Utilities.get_line_from_routes_list(routes)}"
    end
  end
end
