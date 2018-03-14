defmodule Sign.Static.Messages do
  alias Sign.Message
  alias Sign.Content

  @static_duration 180

  def update_signs(stations) do
    stations
    |> Enum.flat_map(&[{&1, 0}, {&1, 1}])
    |> Enum.map(&update_sign/1)
  end

  defp update_sign({station, direction}) do
    text = text_for_station_code(station.stop_id, direction)
    build_content(station, direction, text)
  end

  defp build_content(station, direction, text) do
    headsign = Message.headsign(direction, "Mattapan", station.stop_id)
    message_text = Sign.Message.format_message(headsign, text)
    message = %Message{placement: placement(station, direction), message: [{message_text, nil}], duration: @static_duration}
    nil_message = %Message{placement: placement_hack(station, direction), message: [{"                  ", nil}]}
    %Content{station: station.stop_id, messages: [message, nil_message]}
  end

  defp placement(station, direction) do
    sign_label = Map.get(station.zones, direction)
    [Message.sign_code(sign_label) <> "1"]
  end

  defp placement_hack(station, direction) do
    sign_label = Map.get(station.zones, direction)
    [Message.sign_code(sign_label) <> "2"]
  end

  defp text_for_station_code(_code, _direction) do
    "Soon"
  end
end
