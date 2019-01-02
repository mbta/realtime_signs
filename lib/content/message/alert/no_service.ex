defmodule Content.Message.Alert.NoService do
  @moduledoc """
  A message displayed when a station is closed due to shuttles or a suspension
  """

  defstruct []

  @type t :: %__MODULE__{}

  defimpl Content.Message do
    def to_string(_) do
      "No train service"
    end
  end
end
