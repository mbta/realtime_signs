defmodule Headway.ScheduleHeadway do

  @schedule_api_url "https://api-v3.mbta.com/schedules"

  def build_request(station_ids) do
    @schedule_api_url <> "?sort=arrival_time&filter[stop_id]=#{Enum.join(station_ids, ",")}"
  end

  def group_headways_for_stations(schedules, station_ids, current_time) do
    Map.new(station_ids, fn station_id -> {station_id, headway_for_station(schedules, station_id, current_time)} end)
  end

  defp headway_for_station(schedules, station_id, current_time) do
    relevant_schedules = schedules
                         |> Enum.filter(fn schedule -> get_in(schedule, ["relationships", "stop", "data", "id"]) == station_id end)
                         |> Enum.map(&schedule_time/1)
                         |> Enum.sort(&Timex.compare/2)
    {previous_times, later_times} = Enum.split_with(relevant_schedules, fn schedule_time -> Time.compare(schedule_time, current_time) == :lt end)
    headway_times = [List.last(previous_times) | Enum.take(later_times, 2)]
    calculate_headway(headway_times)
  end

  defp calculate_headway([previous_time, next_time]) do
    {Timex.diff(previous_time, next_time, :minutes), nil}
  end
  defp calculate_headway([previous_time, current_time, next_time]) do
    {Timex.diff(previous_time, current_time, :minutes), Timex.diff(current_time, next_time, :minutes)}
  end
  defp calculate_headway(_), do: {nil, nil}

  defp schedule_time(schedule) do
    departure_time = get_in(schedule, ["attributes", "departure_time"])
    departure_time || get_in(schedule, ["attributes", "arrival_time"])
  end

  defp format_headway({nil, nil}), do: ""
  defp format_headway({x, y}) when x == y or is_nil(y), do: "Every #{x} min"
  defp format_headway({x, y}), do: "Every #{x} to #{y} min"
end
