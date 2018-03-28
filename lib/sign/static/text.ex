defmodule Sign.Static.Text do
  require Logger
  alias Headway.ScheduleHeadway
  @type t :: {String.t, String.t}

  @empty_message {"", ""}

  @spec text_for_headway(ScheduleHeadway.t, DateTime.t, String.t, String.t) :: t
  def text_for_headway({nil, nil}, _current_time, _headsign, _vehicle_name) do
    @empty_message
  end
  def text_for_headway({:first_departure, headway, first_departure}, current_time, headsign, vehicle_name) do
    text_between_service_days(first_departure, current_time, headway, headsign, vehicle_name)
  end
  def text_for_headway({:last_departure, last_departure}, _current_time, _headsign, vehicle_name) do
    text_for_last_departure(last_departure, vehicle_name)
  end
  def text_for_headway(headway, _current_time, headsign, vehicle_name) do
    {"#{vehicle_name} to #{headsign}", ScheduleHeadway.format_headway_range(headway)}
  end

  @spec text_for_raised_bridge() :: t
  def text_for_raised_bridge() do
    {"Bridge is up", "Expect SL3 delays"}
  end

  @spec text_between_service_days(DateTime.t, DateTime.t, ScheduleHeadway.t, String.t, String.t) :: t
  defp text_between_service_days(first_departure, current_time, headway, headsign, vehicle_name) do
    max_headway = ScheduleHeadway.max_headway(headway)
    time_buffer = if max_headway, do: max_headway, else: 0
    if show_first_departure?(first_departure, current_time, time_buffer) do
      {"#{vehicle_name} to #{headsign}", ScheduleHeadway.format_headway_range(headway)}
    else
      @empty_message
    end
  end

  @spec text_for_last_departure(DateTime.t, String.t) :: t
  defp text_for_last_departure(last_departure, vehicle_name) do
    case Timex.format(last_departure, "{h12}:{m}{AM}") do
      {:ok, time_string} ->
        {"Last #{singular_vehicle_name(vehicle_name)}", "Scheduled for #{time_string}"}
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

  @spec singular_vehicle_name(String.t) :: String.t
  defp singular_vehicle_name("Buses"), do: "Bus"
  defp singular_vehicle_name(vehicle_name), do: vehicle_name
end
