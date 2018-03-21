defmodule Sign.PredictionsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Sign.Predictions

  describe "handle_info/3" do
    test "handles 500 status code" do
      status_error_url = "https://api-v3.mbta.com/schedules?filter[stop]=500_error"
      opts = [vehicle_positions_url: status_error_url, trip_updates_url: "", name: :test]
      log = capture_log [level: :warn], fn -> 
        handle_info(:download, opts)
      end

      assert log =~ "Status code 500"
    end

    test "handles http error" do
      error_url = "https://api-v3.mbta.com/schedules?filter[stop]=unknown_error"
      opts = [vehicle_positions_url: error_url, trip_updates_url: "", name: :test]
      log = capture_log [level: :warn], fn -> 
        handle_info(:download, opts)
      end

      assert log =~ "Bad URL"
    end

    test "handles unknown error" do
      unknown_error_url = "unknown"
      opts = [vehicle_positions_url: unknown_error_url, trip_updates_url: "", name: :test]
      log = capture_log [level: :warn], fn -> 
        handle_info(:download, opts)
      end

      assert log =~ "unknown reason"
    end
  end
end
