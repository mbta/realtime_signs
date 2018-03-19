defmodule Headway.ScheduleHeadway do
  require Logger

  @schedule_api_url "https://api-v3.mbta.com/schedules"

  def build_request(station_ids) do
    id_filter = station_ids |> Enum.map(&URI.encode/1) |> Enum.join(",")
    @schedule_api_url <> "?filter[stop]=#{id_filter}"
  end

  def group_headways_for_stations(schedules, station_ids, current_time) do
    Map.new(station_ids, fn station_id -> {station_id, headway_for_station(schedules, station_id, current_time)} end)
  end

  defp headway_for_station(schedules, station_id, current_time) do
    schedules
    |> Enum.filter(fn schedule -> get_in(schedule, ["relationships", "stop", "data", "id"]) == station_id end)
    |> Enum.flat_map(&schedule_time/1)
    |> Enum.sort(&Timex.compare(&1, &2) <= 0)
    |> Enum.split_with(fn schedule_time -> DateTime.compare(schedule_time, current_time) == :lt end)
    |> do_headway_for_station
  end

  defp do_headway_for_station({previous_times, later_times}) when previous_times == [] or later_times == [] do
    {nil, nil}
  end
  defp do_headway_for_station({previous_times, later_times}) do
    calculate_headway([List.last(previous_times) | Enum.take(later_times, 2)])
  end

  defp calculate_headway([previous_time, upcoming_time]) do
    {Timex.diff(upcoming_time, previous_time , :minutes), nil}
  end
  defp calculate_headway([previous_time, upcoming_time, second_upcoming_time]) do
    {Timex.diff(upcoming_time, previous_time, :minutes), Timex.diff(second_upcoming_time, upcoming_time, :minutes)}
  end

  defp schedule_time(schedule) do
    departure_time = get_in(schedule, ["attributes", "departure_time"])
    time = departure_time || get_in(schedule, ["attributes", "arrival_time"])
    case time do
      nil -> []
      time -> parse_schedule_time(time)
    end
  end

  defp parse_schedule_time(time) do
    case Timex.parse(time, "{ISO:Extended}") do
      {:ok, parsed_time} ->
        [parsed_time]
      {:error, reason} ->
        Logger.warn("Could not parse time: #{inspect reason}")
        []
    end
  end

  def format_headway({nil, nil}), do: ""
  def format_headway({x, y}) when x == y or is_nil(y), do: "Every #{x} min"
  def format_headway({x, y}) when x > y, do: "Every #{y} to #{x} min"
  def format_headway({x, y}), do: "Every #{x} to #{y} min"
end
