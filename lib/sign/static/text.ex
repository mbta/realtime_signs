defmodule Sign.Static.Text do
  require Logger
  alias Headway.ScheduleHeadway
  @type t :: {String.t, String.t}

  @empty_message {"", ""}
  @chelsea_outbound_message {"Drop off only", "Board opposite side"}

  @spec text_for_headway(ScheduleHeadway.t, DateTime.t, String.t, String.t, String.t) :: t
  def text_for_headway({nil, nil}, _current_time, _headsign, _vehicle_name, _station_id) do
    @empty_message
  end
  def text_for_headway({:first_departure, headway, first_departure}, current_time, headsign, vehicle_name, station_id) do
    text_between_service_days(first_departure, current_time, headway, headsign, vehicle_name, station_id)
  end
  def text_for_headway(_headway, _current_time, _headsign, _vehicle_name, "74630") do
    @chelsea_outbound_message
  end
  def text_for_headway(headway, _current_time, headsign, vehicle_name, _station_id) do
    {"#{pluralize(vehicle_name)} to #{headsign}", ScheduleHeadway.format_headway_range(headway)}
  end

  @spec text_for_raised_bridge() :: t
  def text_for_raised_bridge() do
    {"Bridge is up", "Expect SL3 delays"}
  end

  @spec text_between_service_days(DateTime.t, DateTime.t, ScheduleHeadway.t, String.t, String.t, String.t) :: t
  defp text_between_service_days(first_departure, current_time, headway, headsign, vehicle_name, station_id) do
    max_headway = ScheduleHeadway.max_headway(headway)
    time_buffer = if max_headway, do: max_headway, else: 0
    if ScheduleHeadway.show_first_departure?(first_departure, current_time, time_buffer) do
      first_departure_message(vehicle_name, headsign, headway, station_id)
    else
      @empty_message
    end
  end

  defp first_departure_message(_vehicle_name, _headsign, _headway, "74630") do
    @chelsea_outbound_message
  end
  defp first_departure_message(vehicle_name, headsign, headway, _station_id) do
    {"#{pluralize(vehicle_name)} to #{headsign}", ScheduleHeadway.format_headway_range(headway)}
  end

  @spec pluralize(String.t) :: String.t
  defp pluralize("Trolley"), do: "Trolley" # intentionally singular for character limit
  defp pluralize(vehicle), do: Inflex.pluralize(vehicle)
end
