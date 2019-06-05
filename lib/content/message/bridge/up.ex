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
    def to_string(%Content.Message.Bridge.Up{duration: nil}) do
      "Chelsea St Bridge is up"
    end

    def to_string(%Content.Message.Bridge.Up{duration: duration}) do
      unit = if duration == 1, do: "minute", else: "minutes"
      [{"Chelsea St Bridge is up", 2}, {"for #{duration} more #{unit}", 2}]
    end
  end
end
