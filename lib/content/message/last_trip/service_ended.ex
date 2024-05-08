defmodule Content.Message.LastTrip.ServiceEnded do
  @moduledoc """
  A message displayed when a station is closed
  """
  @enforce_keys []
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  defimpl Content.Message do
    def to_string(%Content.Message.LastTrip.ServiceEnded{}) do
      "Service ended for night"
    end
  end
end
