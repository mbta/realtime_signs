defmodule Sign.Platforms do
  defstruct mz: false, cp: false, nb: false, sb: false, eb: false, wb: false

  def new, do: %__MODULE__{}

  def set(state, platform, on \\ true)
  def set(state, :mezzanine, on), do: %{state | mz: on}
  def set(state, :center, on), do: %{state | cp: on}
  def set(state, :northbound, on), do: %{state | nb: on}
  def set(state, :southbound, on), do: %{state | sb: on}
  def set(state, :eastbound, on), do: %{state | eb: on}
  def set(state, :westbound, on), do: %{state | wb: on}

  def from_zones(zones) do
    Enum.reduce(zones, new(), &do_for_zones/2)
  end

  defp do_for_zones(zone, acc), do: set(acc, zone, true)

  def to_string(state) do
    [state.mz, state.cp, state.nb, state.sb, state.eb, state.wb]
    |> Enum.map(&platform_to_string/1)
    |> Enum.join("")
  end

  defp platform_to_string(true), do: "1"
  defp platform_to_string(false), do: "0"
  defp platform_to_string(i) when is_integer(i), do: Integer.to_string(i)
  defp platform_to_string(s), do: s
end
