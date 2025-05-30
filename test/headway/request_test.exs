defmodule Headway.RequestTest do
  use ExUnit.Case, async: true
  require Logger
  import ExUnit.CaptureLog
  import Headway.Request

  describe "get_schedules/1" do
    test "gracefully handles bad responses and logs warning" do
      log =
        capture_log([level: :warning], fn ->
          assert get_schedules(["500_error"]) == :error
          assert get_schedules(["unknown_error"]) == :error
        end)

      assert log =~ "Response returned with status code 500"
      assert log =~ "Could not load schedules"
      assert log =~ "Bad URL"
    end
  end

  describe "build_request/1" do
    test "builds request with comma separated station ids and direction IDs" do
      assert build_request({~w[0 1], ["7022", "1123"]}) ==
               "https://api-dev-green.mbtace.com/schedules?filter[stop]=7022,1123&filter[direction_id]=0,1"

      assert build_request({["1"], ["7022"]}) ==
               "https://api-dev-green.mbtace.com/schedules?filter[stop]=7022&filter[direction_id]=1"
    end
  end

  test "Logs warning when json data cannot be parsed" do
    log =
      capture_log([level: :warning], fn ->
        assert get_schedules(["parse_error"]) == []
      end)

    assert log =~ "Could not decode response for scheduled headways:"
  end

  test "parses valid json" do
    assert get_schedules(["valid_json"]) == [%{"relationships" => "trip"}]
  end
end
