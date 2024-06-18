defmodule Content.Message.LastTrip.StationClosed do
  @moduledoc """
  A message displayed when a station is closed
  """
  @enforce_keys []
  defstruct @enforce_keys ++ [routes: []]

  @type t :: %__MODULE__{}

  defimpl Content.Message do
    def to_string(%Content.Message.LastTrip.StationClosed{routes: routes}) do
      case PaEss.Utilities.get_line_from_routes_list(routes) do
        "train" -> "Station closed"
        line -> "No #{line}"
      end
    end
  end
end
