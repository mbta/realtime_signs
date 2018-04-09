defmodule Content.Predictions do
  defstruct [times: []]

  def from_times(times) do
    %__MODULE__{times: times}
  end

  def to_text(%__MODULE__{times: times}) do
    "Next trains in #{Enum.join(times, ", ")} seconds"
  end
end
