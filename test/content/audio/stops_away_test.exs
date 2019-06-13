defmodule Content.Audio.StopsAwayTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "to_params/1" do
    test "Serializes correctly" do
      audio = %Content.Audio.StopsAway{destination: :alewife, stops_away: 2}

      assert Content.Audio.to_params(audio) ==
               {"108", ["501", "507", "4000", "533", "5002", "534"], :audio}
    end

    test "Uses singular 'stop' if 1 stop away" do
      audio = %Content.Audio.StopsAway{destination: :alewife, stops_away: 1}

      assert Content.Audio.to_params(audio) ==
               {"108", ["501", "507", "4000", "533", "5001", "535"], :audio}
    end
  end

  describe "from_message/1" do
    test "Converts a stopped train message with known headsign" do
      msg = %Content.Message.StopsAway{headsign: "Frst Hills", stops_away: 1}

      assert Content.Audio.StopsAway.from_message(msg) ==
               %Content.Audio.StopsAway{destination: :forest_hills, stops_away: 1}
    end

    test "Logs a warning if unknown headsign" do
      msg = %Content.Message.StopsAway{headsign: "Unknown", stops_away: 1}

      log =
        capture_log([level: :warn], fn ->
          assert Content.Audio.StopsAway.from_message(msg) == nil
        end)

      assert log =~ "unknown_headsign"
    end

    test "Returns nil for irrelevant message" do
      msg = %Content.Message.Empty{}
      assert Content.Audio.StopsAway.from_message(msg) == nil
    end
  end
end
