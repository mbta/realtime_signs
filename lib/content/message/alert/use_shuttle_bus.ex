defmodule Content.Message.Alert.UseShuttleBus do
  @moduledoc """
  A message displayed when a station is closed due to shuttles
  """

  defstruct []

  @type t :: %__MODULE__{}

  defimpl Content.Message do
    def to_string(_) do
      "Use shuttle bus"
    end
  end
end
