defmodule Sign.Static.Text do
  require Logger
  alias Headway.ScheduleHeadway
  @empty_message {"", ""}

  def text_for_station_code(_code, _direction, {nil, nil}, _current_time) do
    @empty_message
  end
  def text_for_station_code(_code, _direction, {:first_departure, headway, first_departure}, current_time) do
    text_for_first_departure(first_departure, current_time, headway)
  end
  def text_for_station_code(_code, _direction, {:last_departure, last_departure}, _current_time) do
    text_for_last_departure(last_departure)
  end
  def text_for_station_code(_code, _direction, headway, _current_time) do
    {"Trolley to Ashmont", ScheduleHeadway.format_headway_range(headway)}
  end

  defp text_for_first_departure(first_departure, current_time, headway) do
    max_headway = ScheduleHeadway.max_headway(headway)
    if show_first_departure?(first_departure, current_time, max_headway) do
      {"Trolley to Ashmont", ScheduleHeadway.format_headway_range(headway)}
    else
      @empty_message
    end
  end

  defp text_for_last_departure(last_departure) do
    case Timex.format!(last_departure, "{h12}:{m}{AM}") do
      {:ok, time_string} ->
        {"Last Trolley", "Scheduled for #{time_string}"}
      _ ->
        Logger.warn("Could not format departure time #{inspect last_departure}")
        @empty_message
    end
  end

  defp show_first_departure?(first_departure, current_time, max_headway) do
    earliest_time = Timex.shift(first_departure, minutes: max_headway * -1)
    Time.compare(current_time, earliest_time) != :lt
  end
end
