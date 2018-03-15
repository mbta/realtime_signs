defmodule Sign.Static.Messages do
  alias Sign.Message
  alias Sign.Content
  alias Sign.Station

  @static_duration 180

  @doc "Returns a Content struct representing the static messages that will be displayed for given stations"
  def station_messages(stations) do
    stations
    |> Enum.flat_map(&station_with_zones/1)
    |> Enum.map(&station_message/1)
  end

  defp station_message({station, direction}) do
    text = text_for_station_code(station.stop_id, direction)
    build_content(station, direction, text)
  end

  defp station_with_zones(station) do
    Enum.map(Station.zone_ids(station), &{station, &1})
  end

  defp build_content(station, direction, text) do
    headsign = Message.headsign(direction, station.route_id, station.stop_id)
    message_text = Sign.Message.format_message(headsign, text)
    message = %Message{placement: placement(station, direction), message: [{message_text, nil}], duration: @static_duration}
    %Content{station: station.stop_id, messages: [message]}
  end

  defp placement(station, direction) do
    sign_label = Map.get(station.zones, direction)
    [Message.sign_code(sign_label) <> "1"]
  end

  defp text_for_station_code(_code, _direction) do
    "Welcome!"
  end
end
