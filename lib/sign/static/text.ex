defmodule Sign.Static.Text do
  require Logger
  alias Headway.ScheduleHeadway
  @type t :: {String.t, String.t}

  @empty_message {"", ""}

  @spec text_for_headway(ScheduleHeadway.t, DateTime.t) :: t
  def text_for_headway({nil, nil}, _current_time) do
    @empty_message
  end
  def text_for_headway({:first_departure, headway, first_departure}, current_time) do
    text_between_service_days(first_departure, current_time, headway)
  end
  def text_for_headway({:last_departure, last_departure}, _current_time) do
    text_for_last_departure(last_departure)
  end
  def text_for_headway(headway, _current_time) do
    {"Trolley to Ashmont", ScheduleHeadway.format_headway_range(headway)}
  end

  def text_for_raised_bridge() do
    {"Bridge is up", "Expect SL3 delays"}
  end

  @spec text_between_service_days(DateTime.t, DateTime.t, ScheduleHeadway.t) :: t
  defp text_between_service_days(first_departure, current_time, headway) do
    max_headway = ScheduleHeadway.max_headway(headway)
    time_buffer = if max_headway, do: max_headway, else: 0
    if show_first_departure?(first_departure, current_time, time_buffer) do
      {"Trolley to Ashmont", ScheduleHeadway.format_headway_range(headway)}
    else
      @empty_message
    end
  end

  @spec text_for_last_departure(DateTime.t) :: t
  defp text_for_last_departure(last_departure) do
    case Timex.format(last_departure, "{h12}:{m}{AM}") do
      {:ok, time_string} ->
        {"Last Trolley", "Scheduled for #{time_string}"}
      _ ->
        Logger.warn("Could not format departure time #{inspect last_departure}")
        @empty_message
    end
  end

  @spec show_first_departure?(DateTime.t, DateTime.t, non_neg_integer) :: boolean
  defp show_first_departure?(first_departure, current_time, max_headway) do
    earliest_time = Timex.shift(first_departure, minutes: max_headway * -1)
    Time.compare(current_time, earliest_time) != :lt
  end
end
