defmodule Content.Message.Bridge.Up do
  @moduledoc """
  A message to be used when the route is affected by a bridge being up
  """

  defstruct [:duration]

  @type t :: %__MODULE__{duration: integer() | nil}

  @spec new(integer() | nil) :: t()
  def new(duration) do
    %__MODULE__{duration: duration}
  end

  defimpl Content.Message do
    def to_string(_) do
      "Bridge is up"
    end
  end
end
