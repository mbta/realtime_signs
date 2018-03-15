defmodule Sign.Static.Messages do
  alias Sign.Message
  alias Sign.Content
  alias Sign.Station

  @additional_duration 60

  @doc "Returns a Content struct representing the static messages that will be displayed for given stations"
  def station_messages(stations, refresh_rate) do
    stations
    |> Enum.flat_map(&station_with_zones/1)
    |> Enum.map(&build_content(&1, refresh_rate))
  end

  defp build_content({station, direction}, refresh_rate) do
    %Content{station: station.stop_id, messages: build_messages(station, direction, refresh_rate)}
  end

  defp build_messages(station, direction, refresh_rate) do
    duration = message_duration(refresh_rate)
    {text_top, text_bottom} = text_for_station_code(station.stop_id, direction)
    message_line_top = build_message(station, direction, text_top, duration, :top)
    message_line_bottom = build_message(station, direction, text_bottom, duration, :bottom)
    [message_line_top, message_line_bottom]
  end

  defp build_message(station, direction, text, duration, line_value) do
    placement = placement_code(station, direction, Sign.Message.line_code(line_value))
    %Message{placement: placement, message: [{text, nil}], duration: duration}
  end

  defp message_duration(refresh_rate_milliseconds) do
    refresh_rate_seconds = div(refresh_rate_milliseconds, 1_000)
    refresh_rate_seconds + additional_duration()
  end

  defp placement_code(station, direction, line_placement) do
    sign_label = Map.get(station.zones, direction)
    [Message.sign_code(sign_label) <> line_placement]
  end

  defp additional_duration() do
    if Mix.env == :test, do: 0, else: @additional_duration
  end

  defp station_with_zones(station) do
    Enum.map(Station.zone_ids(station), &{station, &1})
  end

  defp text_for_station_code(_code, _direction) do
    {"Trolley to Ashmont", "Every 4 to 8 min"}
  end
end
