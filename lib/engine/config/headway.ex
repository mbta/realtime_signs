defmodule Engine.Config.Headway do
  @enforce_keys [:headway_id, :range_high, :range_low]
  defstruct @enforce_keys

  @type headway_group :: String.t()
  @type time_period :: :peak | :off_peak | :saturday | :sunday
  @type headway_id :: {headway_group(), time_period()}

  @type t :: %__MODULE__{
          headway_id: headway_id(),
          range_high: integer(),
          range_low: integer()
        }

  @spec from_map(String.t(), String.t(), any()) :: {:ok, t()} | :error
  def from_map(group, time_period, %{"range_high" => high, "range_low" => low})
      when is_integer(high) and is_integer(low) do
    case parse_time_period(time_period) do
      {:ok, time_period} ->
        {:ok,
         %__MODULE__{
           headway_id: {group, time_period},
           range_high: high,
           range_low: low
         }}

      :error ->
        :error
    end
  end

  def from_map(_, _, _), do: :error

  @spec current_time_period(DateTime.t()) :: time_period()
  def current_time_period(dt) do
    # Subtract 3 hours, since the service day ends at 3 AM
    day_of_week = DateTime.add(dt, -3, :hour) |> Date.day_of_week()

    rush_hour? =
      (dt.hour >= 7 and dt.hour < 9) or (dt.hour >= 16 and dt.hour < 18) or
        (dt.hour == 18 and dt.minute <= 30)

    case {day_of_week, rush_hour?} do
      {6, _} -> :saturday
      {7, _} -> :sunday
      {_, true} -> :peak
      {_, false} -> :off_peak
    end
  end

  @spec parse_time_period(String.t()) :: {:ok, time_period()} | :error
  defp parse_time_period("peak"), do: {:ok, :peak}
  defp parse_time_period("off_peak"), do: {:ok, :off_peak}
  defp parse_time_period("saturday"), do: {:ok, :saturday}
  defp parse_time_period("sunday"), do: {:ok, :sunday}
  defp parse_time_period(_), do: :error
end
