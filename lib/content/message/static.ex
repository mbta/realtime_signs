defmodule Content.Message.Static do
  @moduledoc """
  A static message for a sign, for use in sending arbitrary text for announcements
  """

  defstruct [:text]

  @type t :: %__MODULE__{
    text: String.t()
  }

  @spec new(String.t) :: t()
  def new(text) do
    %__MODULE__{
      text: text
    }
  end

  defimpl Content.Message do
    def to_string(%{text: text}) do
      text
    end
  end
end
