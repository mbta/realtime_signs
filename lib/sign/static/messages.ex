defmodule Sign.Static.Messages do
  alias Sign.Message
  alias Sign.Content
  alias Sign.Station

  @additional_duration 60

  @doc "Returns a Content struct representing the static messages that will be displayed for given stations"
  def station_messages(stations, refresh_rate) do
    stations
    |> Enum.flat_map(&station_with_zones/1)
    |> Enum.map(&station_message(&1, refresh_rate))
  end

  defp station_message({station, direction}, refresh_rate) do
    text = text_for_station_code(station.stop_id, direction)
    build_content(station, direction, text, refresh_rate)
  end

  defp station_with_zones(station) do
    Enum.map(Station.zone_ids(station), &{station, &1})
  end

  defp build_content(station, direction, text, refresh_rate) do
    headsign = Message.headsign(direction, station.route_id, station.stop_id)
    message_text = Sign.Message.format_message(headsign, text)
    duration = message_duration(refresh_rate)
    message = %Message{placement: placement(station, direction), message: [{message_text, nil}], duration: duration}
    %Content{station: station.stop_id, messages: [message]}
  end

  defp message_duration(refresh_rate_milliseconds) do
    refresh_rate_seconds = div(refresh_rate_milliseconds, 1_000)
    refresh_rate_seconds + additional_duration()
  end

  defp placement(station, direction) do
    sign_label = Map.get(station.zones, direction)
    [Message.sign_code(sign_label) <> "1"]
  end

  defp additional_duration() do
    if Mix.env == :test, do: 0, else: @additional_duration
  end

  defp text_for_station_code(_code, _direction) do
    "Welcome!"
  end
end
