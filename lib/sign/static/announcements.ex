defmodule Sign.Static.Announcements do
  alias Headway.ScheduleHeadway
  alias Sign.{Station, Canned, Platforms, Stations, Message}
  alias Bridge.Chelsea

  @typep language :: :english | :spanish

  @english_headway_modifier 5500
  @spanish_headway_modifier 37000

  @spec from_schedule_headways(%{Station.id => ScheduleHeadway.t}, DateTime.t, Chelsea.status) :: [Message.t]
  def from_schedule_headways(headways, current_time, bridge_status) do
    [:english, :spanish]
    |> Enum.flat_map(&do_from_schedule_headways(headways, current_time, bridge_status, &1))
    |> Enum.filter(& &1)
  end

  @spec do_from_schedule_headways(%{Station.id => ScheduleHeadway.t}, DateTime.t, Chelsea.status, language) :: [Message.t]
  defp do_from_schedule_headways(headways, current_time, bridge_status, language) do
    Enum.flat_map(headways, &station_announcement(&1, current_time, bridge_status, language))
  end

  defp station_announcement({station_id, _headway}, _current_time, {"Raised", duration}, language) do
    station = Stations.Live.for_gtfs_id(station_id)
    [%Canned{
       mid: mid_for_bridge(duration, language),
       type: 0,
       platforms: get_platforms(station),
       station: station.sign_id,
       variables: variables_for_bridge(duration, language),
       timeout: 200
     }]
  end

  defp station_announcement({station_id, headway}, current_time, _bridge_status, language) do
    station = Stations.Live.for_gtfs_id(station_id)
    Enum.map(station.zones, &headway_announcement(station, headway, current_time, &1, language))
  end

  defp headway_announcement(station, {:first_departure, headway_range, first_departure}, current_time, direction, language) do
    max_headway = ScheduleHeadway.max_headway(headway_range)
    if ScheduleHeadway.show_first_departure?(first_departure, current_time, max_headway) do
      headway_announcement(station, headway_range, current_time, direction, language)
    else
      nil
    end
  end
  defp headway_announcement(station, headway, current_time, {direction, zone_location}, language) do
    platform = Platforms.new() |> Platforms.set(zone_location)
    %Canned{
      mid: mid_for_headway(headway, direction, language),
      type: 0,
      platforms: platform,
      station: station.sign_id,
      variables: variables_for_headway(headway, current_time, language)
    }
  end

  defp get_platforms(station) do
    station
    |> Station.zones()
    |> Platforms.from_zones()
  end

  defp mid_for_bridge(nil, :english), do: 136
  defp mid_for_bridge(_duration, :english), do: 135
  defp mid_for_bridge(nil, :spanish), do: 153
  defp mid_for_bridge(_duration, :spanish), do: 152

  defp mid_for_headway(_headway, 0, :english), do: 133
  defp mid_for_headway(_headway, 1, :english), do: 134

  defp mid_for_headway(_headway, 0, :spanish), do: 150
  defp mid_for_headway(_headway, 1, :spanish), do: 151

  defp variables_for_bridge(nil, _), do: []
  defp variables_for_bridge(duration, language), do: do_variables_for_bridge(duration / 60, language)

  defp do_variables_for_bridge(minutes, :english) when minutes <= 5, do: [5505]
  defp do_variables_for_bridge(minutes, :english) when minutes <= 10, do: [5510]
  defp do_variables_for_bridge(minutes, :english) when minutes <= 15, do: [5515]
  defp do_variables_for_bridge(minutes, :english) when minutes <= 20, do: [5520]
  defp do_variables_for_bridge(minutes, :english) when minutes <= 25, do: [5525]
  defp do_variables_for_bridge(_minutes, :english), do: [5530]

  defp do_variables_for_bridge(minutes, :spanish) when minutes <= 5, do: [37005]
  defp do_variables_for_bridge(minutes, :spanish) when minutes <= 10, do: [37010]
  defp do_variables_for_bridge(minutes, :spanish) when minutes <= 15, do: [37015]
  defp do_variables_for_bridge(minutes, :spanish) when minutes <= 20, do: [37020]
  defp do_variables_for_bridge(minutes, :spanish) when minutes <= 25, do: [37025]
  defp do_variables_for_bridge(_minutes, :spanish), do: [37030]

  defp variables_for_headway(headway, current_time, language) do
    id_modifier = if language == :spanish, do: @spanish_headway_modifier, else: @english_headway_modifier
    do_variables_for_headway(headway, current_time, id_modifier)
  end

  defp do_variables_for_headway({x, y}, _current_time, id_modifier), do: Enum.sort([x + id_modifier, y + id_modifier])
end
