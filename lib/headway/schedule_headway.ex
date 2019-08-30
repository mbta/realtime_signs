defmodule Headway.ScheduleHeadway do
  require Logger

  @type headway_range ::
          {nil, nil} | {non_neg_integer, nil} | {non_neg_integer, non_neg_integer} | :none
  @type t :: headway_range | {:first_departure, headway_range, DateTime.t()}
  @type schedule_map :: map

  @min_headway 5
  @headway_padding 2
  @max_headway_to_consider 30

  @spec build_request({[String.t()], [GTFS.station_id()]}) :: String.t()
  def build_request({direction_ids, station_ids}) do
    id_filter = station_ids |> Enum.map(&URI.encode/1) |> Enum.join(",")
    direction_filter = direction_ids |> Enum.map(&URI.encode/1) |> Enum.join(",")
    schedule_api_url = Application.get_env(:realtime_signs, :api_v3_url) <> "/schedules"
    schedule_api_url <> "?filter[stop]=#{id_filter}&filter[direction_id]=#{direction_filter}"
  end

  @spec group_headways_for_stations(
          %{String.t() => schedule_map()},
          [GTFS.station_id()],
          DateTime.t()
        ) :: %{
          String.t() => t
        }
  def group_headways_for_stations(schedules, station_ids, current_time) do
    Map.new(station_ids, fn station_id ->
      {station_id, headway_for_station(schedules, station_id, current_time)}
    end)
  end

  @spec headway_for_station(%{String.t() => schedule_map()}, GTFS.station_id(), DateTime.t()) :: t
  defp headway_for_station(schedules, station_id, current_time) do
    (schedules[station_id] || [])
    |> Enum.flat_map(&schedule_time/1)
    |> Enum.sort(&(Timex.compare(&1, &2) <= 0))
    |> Enum.split_with(fn schedule_time ->
      DateTime.compare(schedule_time, current_time) == :lt
    end)
    |> do_headway_for_station
  end

  @spec do_headway_for_station({[DateTime.t()], [DateTime.t()]}) :: headway_range
  defp do_headway_for_station({_previous_times, []}), do: {nil, nil}

  defp do_headway_for_station({[], [first_time | _rest] = later_times}) do
    headway_range = later_times |> Enum.take(3) |> calculate_headway_range()
    {:first_departure, headway_range, first_time}
  end

  defp do_headway_for_station({previous_times, later_times}) do
    calculate_headway_range([List.last(previous_times) | Enum.take(later_times, 3)])
  end

  @spec calculate_headway_range([DateTime.t()]) :: headway_range
  defp calculate_headway_range([previous_time, upcoming_time]) do
    actual_headway = {Timex.diff(upcoming_time, previous_time, :minutes), nil}
    pad_headway_range(actual_headway)
  end

  defp calculate_headway_range([previous_time, upcoming_time, second_upcoming_time]) do
    actual_headway =
      {Timex.diff(upcoming_time, previous_time, :minutes),
       Timex.diff(second_upcoming_time, upcoming_time, :minutes)}

    pad_headway_range(actual_headway)
  end

  defp calculate_headway_range([
         previous_time,
         upcoming_time,
         second_upcoming_time,
         third_upcoming_time
       ]) do
    minute_headways = [
      Timex.diff(upcoming_time, previous_time, :minutes),
      Timex.diff(second_upcoming_time, upcoming_time, :minutes),
      Timex.diff(third_upcoming_time, second_upcoming_time, :minutes)
    ]

    {_dropped?, usable_headways} =
      Enum.reduce(minute_headways, {false, []}, fn headway, {dropped?, acc} ->
        if headway <= @max_headway_to_consider or dropped? do
          {dropped?, acc ++ [headway]}
        else
          {true, acc}
        end
      end)

    usable_headways
    |> Enum.take(2)
    |> List.to_tuple()
    |> pad_headway_range()
  end

  @spec schedule_time(map) :: [DateTime.t()]
  defp schedule_time(schedule) do
    departure_time = get_in(schedule, ["attributes", "departure_time"])
    time = departure_time || get_in(schedule, ["attributes", "arrival_time"])

    case time do
      nil -> []
      time -> parse_schedule_time(time)
    end
  end

  @spec parse_schedule_time(String.t()) :: [DateTime.t()]
  defp parse_schedule_time(time) do
    case Timex.parse(time, "{ISO:Extended}") do
      {:ok, parsed_time} ->
        [parsed_time]

      {:error, reason} ->
        Logger.warn("Could not parse time: #{inspect(reason)}")
        []
    end
  end

  @spec show_first_departure?(DateTime.t(), DateTime.t(), non_neg_integer) :: boolean
  def show_first_departure?(first_departure, current_time, max_headway) do
    earliest_time = Timex.shift(first_departure, minutes: max_headway * -1)
    Time.compare(current_time, earliest_time) != :lt
  end

  @spec pad_headway_range(headway_range) :: headway_range
  defp pad_headway_range({x, y}) when x < y, do: do_pad_headway_range({x, y})
  defp pad_headway_range({x, y}), do: do_pad_headway_range({y, x})

  @spec do_pad_headway_range(headway_range) :: headway_range
  defp do_pad_headway_range({x, nil}), do: {pad_lower_value(x), nil}
  defp do_pad_headway_range({x, y}), do: {pad_lower_value(x), pad_upper_value(y)}

  @spec pad_lower_value(integer) :: integer
  defp pad_lower_value(x), do: max(x, @min_headway)

  @spec pad_upper_value(integer) :: integer
  defp pad_upper_value(y), do: max(y, @min_headway) + @headway_padding

  @spec format_headway_range(headway_range()) :: String.t()
  def format_headway_range(:none), do: ""
  def format_headway_range({nil, nil}), do: ""
  def format_headway_range({x, y}) when x == y or is_nil(y), do: "Every #{x} min"
  def format_headway_range({x, y}) when x > y, do: "Every #{y} to #{x} min"
  def format_headway_range({x, y}), do: "Every #{x} to #{y} min"

  @spec format_bottom(Content.Message.Headways.Bottom.t(), DateTime.t()) :: String.t()
  def format_bottom(
        %Content.Message.Headways.Bottom{last_departure: nil, range: range},
        _current_time
      ) do
    format_headway_range(range)
  end

  def format_bottom(
        %Content.Message.Headways.Bottom{last_departure: time, range: range},
        current_time
      ) do
    display =
      current_time
      |> DateTime.diff(time)
      |> Kernel./(60)
      |> Float.ceil(0)
      |> Kernel.trunc()

    [{format_headway_range(range), 3}, {"Departed #{display} min ago", 3}]
  end

  @spec max_headway(headway_range) :: non_neg_integer | nil
  def max_headway({nil, nil}), do: nil
  def max_headway({nil, y}), do: y
  def max_headway({x, nil}), do: x
  def max_headway({x, y}), do: max(x, y)
end
