defmodule Bridge.Chelsea do

  @type status :: {String.t, non_neg_integer | nil}

  @doc "Determines if the given status determines a raised bridge"
  @spec raised?(status | nil) :: boolean
  def raised?({"Raised", _}), do: true
  def raised?(_), do: false
end
