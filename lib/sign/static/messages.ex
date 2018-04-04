defmodule Sign.Static.Messages do
  alias Sign.{Message, Content, Station}
  alias Sign.Static.Text
  alias Headway.ScheduleHeadway

  @additional_duration 60
  @sl3_route_id "743"

  @doc "Returns a Content struct representing the headway messages that will be displayed for given stations"
  @spec station_headway_messages([Station.t], integer, %{Station.id => ScheduleHeadway.t}, DateTime.t, String.t | nil) :: [Content.t]
  def station_headway_messages(stations, refresh_rate, headways, current_time, bridge_status) do
    bridge_raised? = Bridge.Chelsea.raised?(bridge_status)
    stations
    |> Enum.flat_map(&station_with_zones/1)
    |> Enum.map(&build_content(&1, refresh_rate, headways, current_time, bridge_raised?))
  end

  @doc "Returns a Content struct representing the static messages that will be displayed for given stations"
  @spec station_static_messages([Sign.Static.Message.t], non_neg_integer) :: [Content.t]
  def station_static_messages(static_messages, refresh_rate) do
    Enum.map(static_messages, &do_station_static_message(&1, refresh_rate))
  end

  @spec do_station_static_message(Sign.Static.Message.t, non_neg_integer) :: Content.t
  defp do_station_static_message(static_message, refresh_rate) do
    station = Sign.Stations.Live.for_gtfs_id(static_message.station_id)
    text = {static_message.top_text, static_message.bottom_text}
    %Content{station: static_message.sign_id, messages: build_messages(station, static_message.direction, refresh_rate, text)}
  end

  @spec build_content({Station.t, 1 | 0}, integer, map, DateTime.t, boolean) :: Content.t
  defp build_content({station, direction}, refresh_rate, headways, current_time, bridge_raised?) do
    headsign = Sign.Message.headsign(direction, station.route_id, station.id)
    vehicle_name = Sign.Message.vehicle_name(station.route_id)
    message_text = get_text(Map.get(headways, station.id), station.route_id, current_time, bridge_raised?, headsign, vehicle_name)
    %Content{station: station.sign_id, messages: build_messages(station, direction, refresh_rate, message_text)}
  end

  @spec build_messages(Station.t, 1 | 0, integer, Sign.Static.Text.t) :: [Message.t]
  defp build_messages(station, direction, refresh_rate, {text_top, text_bottom}) do
    duration = message_duration(refresh_rate)
    message_line_top = build_message(station, direction, text_top, duration, :top)
    message_line_bottom = build_message(station, direction, text_bottom, duration, :bottom)
    [message_line_top, message_line_bottom]
  end

  @spec build_message(Station.t, 1 | 0, String.t, integer, :top | :bottom) :: Message.t
  defp build_message(station, direction, text, duration, line_value) do
    placement = placement_code(station, direction, Sign.Message.line_code(line_value))
    %Message{placement: placement, message: [{text, nil}], duration: duration}
  end

  @spec message_duration(integer) :: integer
  defp message_duration(refresh_rate_milliseconds) do
    refresh_rate_seconds = div(refresh_rate_milliseconds, 1_000)
    refresh_rate_seconds + additional_duration()
  end

  @spec placement_code(Station.t, 1 | 0, String.t) :: [String.t]
  defp placement_code(station, direction, line_placement) do
    sign_label = Map.get(station.zones, direction)
    [Message.sign_code(sign_label) <> line_placement]
  end

  @spec additional_duration() :: integer
  defp additional_duration() do
    if Mix.env == :test, do: 0, else: @additional_duration
  end

  @spec station_with_zones(Station.t) :: [{Station.t, 1 | 0}]
  defp station_with_zones(station) do
    Enum.map(Station.zone_ids(station), &{station, &1})
  end

  @spec get_text(ScheduleHeadway.t, String.t, DateTime.t, boolean, String.t, String.t) :: Text.t
  defp get_text(headway, route_id, current_time, bridge_raised?, headsign, vehicle_name) do
    if bridge_raised? and route_id == @sl3_route_id do
      Text.text_for_raised_bridge()
    else
      Text.text_for_headway(headway, current_time, headsign, vehicle_name)
    end
  end
end
