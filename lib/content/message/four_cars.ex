defmodule Content.Message.FourCars do
  defstruct []

  defimpl Content.Message do
    def to_string(%Content.Message.FourCars{}) do
      Content.Utilities.width_padded_string("4 cars", "Move to front", 24)
    end
  end
end
