defmodule Bridge.RequestTest do
  use ExUnit.Case
  import Bridge.Request
  import ExUnit.CaptureLog

  describe "get_status/1" do
    test "parses valid response" do
      assert get_status(1) == "Raised"
    end

    test "Logs warning with bad status code" do
      log = capture_log [level: :warn], fn ->
        refute get_status(500)
      end

      assert log =~ "Could not query bridge API: status code 500"
    end

    test "Logs warning when request fails" do
      log = capture_log [level: :warn], fn ->
        refute get_status(754)
      end

      assert log =~ "Could not query bridge API: Unknown error"
    end

    test "Logs warning when parsing fails" do
      log = capture_log [level: :warn], fn ->
        refute get_status(201)
      end

      assert log =~ "Could not parse json response"
    end
  end
end
