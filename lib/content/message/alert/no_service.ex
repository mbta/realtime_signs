defmodule Content.Message.Alert.NoService do
  @moduledoc """
  A message displayed when a station is closed due to shuttles or a suspension
  """

  @enforce_keys []
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  defimpl Content.Message do
    def to_string(_msg) do
      "No train service"
    end
  end
end
