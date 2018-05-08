defmodule Content.Message.Bridge.Up do
  @moduledoc """
  A message to be used when the route is affected by a bridge being up
  """

  defstruct []

  @type t :: %__MODULE__{}

  @spec new() :: t()
  def new() do
    %__MODULE__{}
  end

  defimpl Content.Message do
    def to_string(_) do
      "Bridge is up"
    end
  end
end
