defmodule Content.Message.Bridge.Up do
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
      "Bridge is up"
    end
  end
end
