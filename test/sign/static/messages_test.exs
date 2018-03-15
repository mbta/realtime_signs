defmodule Sign.Static.MessagesTest do
  use ExUnit.Case, async: true
  import Sign.Static.Messages

  @stations [
    %Sign.Station{stop_id: "test", zones: %{0 => :southbound, 1 => :northbound}, route_id: "Mattapan"},
    %Sign.Station{stop_id: "test2", zones: %{0 => :westbound, 1 => :eastbound}, route_id: "Mattapan"}
  ]

  @refresh_rate 1

  describe "station_messages/2" do
    test "messages have correct placement" do
      sign_content_payloads = station_messages(@stations, @refresh_rate)
      station1_placement = Enum.filter(sign_content_payloads, & &1.station == "test")
                           |> Enum.flat_map(& &1.messages)
                           |> Enum.flat_map(& &1.placement)
      station2_placement = Enum.filter(sign_content_payloads, & &1.station == "test2")
                           |> Enum.flat_map(& &1.messages)
                           |> Enum.flat_map(& &1.placement)

      assert station1_placement == ["s1", "n1"]
      assert station2_placement == ["w1", "e1"]
    end

    test "all stations are included in static_messages" do
      sign_content_payloads = station_messages(@stations, @refresh_rate)
      station_codes = Enum.map(sign_content_payloads, & &1.station) |> Enum.uniq
      assert station_codes == ["test", "test2"]
    end

    test "message includes headsigns for direction" do
      sign_content_payloads = station_messages(@stations, @refresh_rate)
      [{test_msg_text, nil}] = Enum.map(sign_content_payloads, & &1.messages) |> List.first |> List.first |> Map.get(:message)
      [{test2_msg_text, nil}] = Enum.map(sign_content_payloads, & &1.messages) |> Enum.at(1) |> List.first |> Map.get(:message)
      assert test_msg_text =~ "Mattapan"
      assert test2_msg_text =~ "Ashmont"
    end
  end
end
