defmodule Content.Message.Bridge.Delays do
  @moduledoc """
  A message for use when the SL3 is delayed by a bridge.
  """

  defstruct []

  @type t :: %__MODULE__{}

  @spec new() :: t()
  def new() do
    %__MODULE__{}
  end

  defimpl Content.Message do
    def to_string(_) do
      "Expect SL3 delays"
    end
  end
end
