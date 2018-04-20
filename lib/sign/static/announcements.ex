defmodule Sign.Static.Announcements do
  alias Headway.ScheduleHeadway
  alias Sign.{Station, Canned, Platforms, Stations, Message}
  alias Bridge.Chelsea

  @typep language :: :english | :spanish

  @english_headway_modifier 5500
  @spanish_headway_modifier 37000
  @headway_mids %{
    {0, :english} => 133,
    {1, :english} => 134,
    {0, :spanish} => 150,
    {1, :spanish} => 151
  }
  @english_bridge_base_var 5500
  @spanish_bridge_base_var 37000
  @bridge_closing_soon_mid %{:english => 136, :spanish => 153}
  @bridge_closing_duration %{:english => 135, :spanish => 152}

  @spec from_schedule_headways(%{Station.id => ScheduleHeadway.t}, DateTime.t, Chelsea.status) :: [Message.t]
  def from_schedule_headways(headways, current_time, bridge_status) do
    [:english, :spanish]
    |> Enum.flat_map(&do_from_schedule_headways(headways, current_time, bridge_status, &1))
  end

  @spec do_from_schedule_headways(%{Station.id => ScheduleHeadway.t}, DateTime.t, Chelsea.status, language) :: [Message.t]
  defp do_from_schedule_headways(headways, current_time, bridge_status, language) do
    Enum.flat_map(headways, &station_announcement(&1, current_time, bridge_status, language))
  end

  defp station_announcement({_station_id, {nil, nil}}, _current_time, _bridge_status, _language) do
    []
  end
  defp station_announcement({_station_id, _headway}, _current_time, {"Raised", _duration}, :spanish) do
    []
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
  defp station_announcement({station_id, {:first_departure, headway_range, first_departure}}, current_time, bridge_status, language) do
    max_headway = ScheduleHeadway.max_headway(headway_range)
    if ScheduleHeadway.show_first_departure?(first_departure, current_time, max_headway) do
      station_announcement({station_id, headway_range}, current_time, bridge_status, language)
    else
      []
    end
  end
  defp station_announcement({"74630", _headway}, _current_time, _bridge_status, _language) do
    []
  end
  defp station_announcement({station_id, headway}, _current_time ,_bridge_status, language) do
    station = Stations.Live.for_gtfs_id(station_id)
    Enum.map(station.zones, &headway_announcement(station, headway, &1, language))
  end

  defp headway_announcement(station, headway, {direction, zone_location}, language) do
    platform = Platforms.new() |> Platforms.set(zone_location)
    %Canned{
      mid: Map.get(@headway_mids, {direction, language}),
      type: 1,
      platforms: platform,
      station: station.sign_id,
      variables: variables_for_headway(headway, language)
    }
  end

  defp get_platforms(station) do
    station
    |> Station.zone_values()
    |> Platforms.from_zones()
  end

  defp mid_for_bridge(nil, language), do: Map.get(@bridge_closing_soon_mid, language)
  defp mid_for_bridge(_duration, language), do: Map.get(@bridge_closing_duration, language)

  defp variables_for_bridge(nil, _), do: []
  defp variables_for_bridge(duration, language), do: do_variables_for_bridge(duration / 60, language)

  defp do_variables_for_bridge(minutes, :english) when minutes <= 5, do: [@english_bridge_base_var + 5]
  defp do_variables_for_bridge(minutes, :english) when minutes <= 10, do: [@english_bridge_base_var + 10]
  defp do_variables_for_bridge(minutes, :english) when minutes <= 15, do: [@english_bridge_base_var + 15]
  defp do_variables_for_bridge(minutes, :english) when minutes <= 20, do: [@english_bridge_base_var + 20]
  defp do_variables_for_bridge(minutes, :english) when minutes <= 25, do: [@english_bridge_base_var + 25]
  defp do_variables_for_bridge(_minutes, :english), do: [@english_bridge_base_var  + 30]
  defp do_variables_for_bridge(minutes, :spanish) when minutes <= 5, do: [@spanish_bridge_base_var + 5]
  defp do_variables_for_bridge(minutes, :spanish) when minutes <= 10, do: [@spanish_bridge_base_var + 10]
  defp do_variables_for_bridge(minutes, :spanish) when minutes <= 15, do: [@spanish_bridge_base_var + 15]
  defp do_variables_for_bridge(minutes, :spanish) when minutes <= 20, do: [@spanish_bridge_base_var + 20]
  defp do_variables_for_bridge(minutes, :spanish) when minutes <= 25, do: [@spanish_bridge_base_var + 25]
  defp do_variables_for_bridge(_minutes, :spanish), do: [@spanish_bridge_base_var + 30]

  defp variables_for_headway(headway, language) do
    id_modifier = if language == :spanish, do: @spanish_headway_modifier, else: @english_headway_modifier
    do_variables_for_headway(headway, id_modifier)
  end

  defp do_variables_for_headway({x, y}, id_modifier), do: Enum.sort([x + id_modifier, y + id_modifier])
end
