defmodule Content.Message.Headways.Bottom do
  require Logger
  defstruct [:range]

  @type t :: %__MODULE__{range: {non_neg_integer(), non_neg_integer()}}

  defimpl Content.Message do
    def to_string(%Content.Message.Headways.Bottom{range: {low, high}}) do
      "Every #{low} to #{high} min"
    end
  end
end
