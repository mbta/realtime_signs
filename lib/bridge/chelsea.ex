defmodule Bridge.Chelsea do

  @type status :: {String.t, non_neg_integer | nil}

  @doc "Determines if the given status determines a raised bridge"
  @spec raised?(status | nil) :: boolean
  def raised?({"Raised", _}), do: true
  def raised?(_), do: false

  def get_duration(estimate_time_string, current_time) do
    estimate_time_string
    |> Timex.parse("{ISO:Extended}")
    |> do_get_duration(current_time)
  end

  defp do_get_duration({:ok, estimate_time}, current_time) do
    Timex.diff(estimate_time, current_time, :seconds)
  end
  defp do_get_duration(_, _current_time) do
    nil
  end
end
