defmodule Bridge.Chelsea do

  @doc "Determines if the given status determines a raised bridge"
  @spec raised?(String.t | nil) :: boolean
  def raised?({"Raised", _}), do: true
  def raised?(_), do: false
end
