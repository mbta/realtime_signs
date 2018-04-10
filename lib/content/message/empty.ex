defmodule Content.Message.Empty do
  @moduledoc """
  The empty sign. If you want to blank what's on there.
  """

  defstruct []

  @type t :: %__MODULE__{}

  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  defimpl Content.Message do
    def to_string(_) do
      ""
    end
  end
end
