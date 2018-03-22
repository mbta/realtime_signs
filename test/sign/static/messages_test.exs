defmodule Sign.Static.MessagesTest do
  use ExUnit.Case, async: true
  import Sign.Static.Messages

  @mattapan_stations [
    %Sign.Station{id: "station_1", sign_id: "test", zones: %{0 => :southbound, 1 => :northbound}, route_id: "Mattapan"},
    %Sign.Station{id: "station_2", sign_id: "test2", zones: %{0 => :westbound, 1 => :eastbound}, route_id: "Mattapan"}
  ]
  @sl3_stations [
    %Sign.Station{id: "sl3_station", sign_id: "SLO", zones: %{0 => :southbound, 1 => :northbound}, route_id: "743"},
    %Sign.Station{id: "sl3_station2", sign_id: "SLF", zones: %{0 => :westbound, 1 => :eastbound}, route_id: "743"}
  ]
  @headway %{"station_1" => {nil, nil}, "station_2" => {nil, nil},
             "sl3_station" => {nil, nil}, "sl3_station2" => {nil, nil}}

  @current_time ~N[2017-07-04 09:00:00]
  @refresh_rate 1

  describe "station_messages/2" do
    test "messages have correct placement" do
      sign_content_payloads = station_messages(@mattapan_stations, @refresh_rate, @headway, @current_time, false)
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
      sign_content_payloads = station_messages(@mattapan_stations, @refresh_rate, @headway, @current_time, "Lowered")
      station_codes = Enum.map(sign_content_payloads, & &1.station) |> Enum.uniq
      assert station_codes == ["test", "test2"]
    end

    test "returns headway in message if one exists" do
      headway = %{@headway | "station_1" => {15, 11}}
      sign_content_payloads = station_messages(@mattapan_stations, @refresh_rate, headway, @current_time, "Lowered")
      messages = sign_content_payloads
                 |> Enum.filter(& &1.station == "test")
                 |> List.first()
                 |> Map.get(:messages)
                 |> Enum.map(&List.first(&1.message))
                 |> Enum.map(fn {txt, _} -> txt end)

      assert "Trolley to Ashmont" in messages
      assert "Every 11 to 15 min" in messages
    end

    test "Returns blank message if no headways are found" do
      sign_content_payloads = station_messages(@mattapan_stations, @refresh_rate, @headway, @current_time, "Lowered")
      messages = sign_content_payloads
                 |> Enum.filter(& &1.station == "test")
                 |> List.first()
                 |> Map.get(:messages)
                 |> Enum.map(&List.first(&1.message))
                 |> Enum.map(fn {txt, _} -> txt end)

      assert messages == ["", ""]
    end

    test "SL3 routes show closed message when bridge is raised" do
      sign_content_payloads = station_messages(@sl3_stations, @refresh_rate, @headway, @current_time, "Raised")
      messages = sign_content_payloads
                 |> List.first()
                 |> Map.get(:messages)
                 |> Enum.map(&List.first(&1.message))
                 |> Enum.map(fn {txt, _} -> txt end)

      assert messages == ["Bridge is up", "Expect SL3 delays"]
    end

    test "SL3 routes behave normally when bridge is lowered" do
      headways = %{@headway | "sl3_station" => {7, 8}}
      sign_content_payloads = station_messages(@sl3_stations, @refresh_rate, headways, @current_time, "Lowered")
      messages = sign_content_payloads
                 |> List.first()
                 |> Map.get(:messages)
                 |> Enum.map(&List.first(&1.message))
                 |> Enum.map(fn {txt, _} -> txt end)

      assert messages == ["Trolley to Ashmont", "Every 7 to 8 min"]
    end

    test "Only SL3 routes change when bridge is raised " do
      headways = %{@headway | "sl3_station" => {7, 8}, "station_1" => {1, 2}}
      stations = @sl3_stations ++ @mattapan_stations
      sign_content_payloads = station_messages(stations, @refresh_rate, headways, @current_time, "Raised")
      mattapan_messages = sign_content_payloads
                 |> Enum.filter(& &1.station == "test")
                 |> List.first()
                 |> Map.get(:messages)
                 |> Enum.map(&List.first(&1.message))
                 |> Enum.map(fn {txt, _} -> txt end)

      sl3_messages = sign_content_payloads
                 |> Enum.filter(& &1.station == "SLO")
                 |> List.first()
                 |> Map.get(:messages)
                 |> Enum.map(&List.first(&1.message))
                 |> Enum.map(fn {txt, _} -> txt end)

      assert mattapan_messages == ["Trolley to Ashmont", "Every 1 to 2 min"]
      assert sl3_messages == ["Bridge is up", "Expect SL3 delays"]
    end
  end
end
