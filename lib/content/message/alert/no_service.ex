defmodule Content.Message.Alert.NoService do
  @moduledoc """
  A message displayed when a station is closed due to shuttles or a suspension
  """

  defstruct routes: []

  @type t :: %__MODULE__{}

  defimpl Content.Message do
    def to_string(%Content.Message.Alert.NoService{routes: routes}) do
      service =
        case PaEss.Utilities.get_line_from_routes_list(routes) do
          "train" -> "train service"
          line -> line
        end

      "No #{service}"
    end
  end
end
