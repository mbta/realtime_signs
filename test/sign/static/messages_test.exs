defmodule Sign.Static.MessagesTest do
  use ExUnit.Case, async: true
  import Sign.Static.Messages

  @stations [
    %Sign.Station{id: "station_1", sign_id: "test", zones: %{0 => :southbound, 1 => :northbound}, route_id: "Mattapan"},
    %Sign.Station{id: "station_2", sign_id: "test2", zones: %{0 => :westbound, 1 => :eastbound}, route_id: "Mattapan"}
  ]
  @headway %{"station_1" => {nil, nil}, "station_2" => {nil, nil}}

  @refresh_rate 1

  describe "station_messages/2" do
    test "messages have correct placement" do
      sign_content_payloads = station_messages(@stations, @refresh_rate, @headway)
      station1_placement = Enum.filter(sign_content_payloads, & &1.station == "test")
                           |> Enum.flat_map(& &1.messages)
                           |> Enum.flat_map(& &1.placement)
      station2_placement = Enum.filter(sign_content_payloads, & &1.station == "test2")
                           |> Enum.flat_map(& &1.messages)
                           |> Enum.flat_map(& &1.placement)

      assert station1_placement == ["s1", "s2", "n1", "n2"]
      assert station2_placement == ["w1", "w2", "e1", "e2"]
    end

    test "all stations are included in static_messages" do
      sign_content_payloads = station_messages(@stations, @refresh_rate, @headway)
      station_codes = Enum.map(sign_content_payloads, & &1.station) |> Enum.uniq
      assert station_codes == ["test", "test2"]
    end
  end
end
