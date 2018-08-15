defmodule Content.Utilities do
  def width_padded_string(left, right, width) do
    max_left_length = width - (String.length(right) + 2)
    left = String.slice(left, 0, max_left_length)
    padding = width - (String.length(left) + String.length(right))
    Enum.join([left, String.duplicate(" ", padding), right])
  end
end
