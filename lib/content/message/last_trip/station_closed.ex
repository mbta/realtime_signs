defmodule Content.Message.LastTrip.StationClosed do
  @moduledoc """
  A message displayed when a station is closed
  """
  @enforce_keys []
  defstruct @enforce_keys ++ [:route]

  @type t :: %__MODULE__{}

  defimpl Content.Message do
    def to_string(%Content.Message.LastTrip.StationClosed{route: route}) do
      if(route, do: "No #{route} Line", else: "Station closed")
    end
  end
end
