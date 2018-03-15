defmodule Sign.Static.StateTest do
  use ExUnit.Case
  import Sign.Static.State
  import ExUnit.CaptureLog

  describe "static_station_codes/1" do
    test "returns station codes for current static_stations" do
      {:ok, static_signs} = start_supervised({Sign.Static.State, [refresh_time: 1, name: :test, stations: ["70262", "70268"]]})
      static_station_codes = static_station_codes(static_signs)
      assert Enum.count(static_station_codes) == 2
      assert "MMIL" in static_station_codes
      assert "RASH" in static_station_codes
    end

    test "refreshes sign according to refresh_time" do
      log = capture_log [level: :info], fn ->
        start_supervised({Sign.Static.State, [refresh_time: 1, name: :refresh_test, stations: ["70268"]]})
        Process.sleep(40)
      end
      assert log =~ "MMIL"
      assert log =~ "Trolley to Ashmont"
    end
  end
end
