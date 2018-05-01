defmodule Signs.HeadwayTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import Signs.Headway

  describe "callback update_content" do
    test "updates the top and bottom contents" do
      sign = %Signs.Headway{
        id: "SIGN",
        pa_ess_id: "1",
        gtfs_stop_id: "123",
        route_id: "743",
        headsign: "Chelsea",
        headway_engine: FakeHeadwayEngine,
        sign_updater: FakeSignUpdater,
        timer: nil
      }

      log = capture_log [level: :info], fn ->
        assert handle_info(:update_content, sign) == {:noreply, %{sign | current_content_top: %Content.Message.Headways.Top{headsign: "Chelsea", vehicle_type: :bus}, current_content_bottom: %Content.Message.Headways.Bottom{range: {1, 2}}}}
      end
      assert log =~ "update_sign called"
    end

    test "when the bottom content does not change, it does not send an update" do
      sign = %Signs.Headway{
        id: "SIGN",
        pa_ess_id: "1",
        gtfs_stop_id: "123",
        route_id: "743",
        headsign: "Chelsea",
        headway_engine: FakeHeadwayEngine,
        sign_updater: FakeSignUpdater,
        timer: nil,
        current_content_top: %Content.Message.Headways.Top{headsign: "Chelsea", vehicle_type: :bus},
        current_content_bottom: %Content.Message.Headways.Bottom{range: {1, 2}}
      }

      log = capture_log [level: :info], fn ->
        handle_info(:update_content, sign)
      end
      assert log != "update_sign called"
    end
  end
end

defmodule FakeHeadwayEngine do
  def get_headways(_stop_id) do
    {1, 2}
  end
end

defmodule FakeSignUpdater do
  require Logger
  def update_sign(id, line, message, duration, start) do
    Logger.info "update_sign called"
    {id, line, message, duration, start}
  end
end
