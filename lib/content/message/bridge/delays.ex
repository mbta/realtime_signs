defmodule Content.Message.Bridge.Delays do
  @moduledoc """
  A static message for a sign, for use in sending arbitrary text for announcements
  """

  defstruct []

  @type t :: %__MODULE__{}

  @spec new() :: t()
  def new() do
  end

  defimpl Content.Message do
    def to_string(_) do
      "Expect SL3 delays"
    end
  end
end
