defmodule Content.Message.LastTrip.StationClosed do
  @moduledoc """
  A message displayed when a station is closed
  """
  @enforce_keys []
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  defimpl Content.Message do
    def to_string(%Content.Message.LastTrip.StationClosed{}) do
      "Station closed"
    end
  end
end
