defmodule Sign.Static.StateTest do
  use ExUnit.Case
  import Sign.Static.State
  import ExUnit.CaptureLog

  describe "static_station_codes/1" do

    setup do
      static_station_config = Application.get_env(:realtime_signs, :headway_stations_config)
      Application.put_env(:realtime_signs, :headway_stations_config, "test/data/static_stations.json")
      on_exit fn ->
        Application.put_env(:realtime_signs, :headway_station_config, static_station_config)
      end
    end

    test "returns station codes for current static_stations" do
      {:ok, static_signs} = start_supervised({Sign.Static.State, [headway_refresh: 1, name: :test]})
      static_station_codes = static_station_codes(static_signs)
      assert Enum.count(static_station_codes) == 2
      assert "MMIL" in static_station_codes
      assert "RASH" in static_station_codes
    end

    test "refreshes sign according to refresh_time" do
      log = capture_log [level: :info], fn ->
        start_supervised({Sign.Static.State, [headway_refresh: 1, name: :refresh_test]})
        Process.sleep(40)
      end
      assert log =~ "MMIL"
    end
  end
end
