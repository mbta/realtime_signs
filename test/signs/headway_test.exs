defmodule Signs.HeadwayTest do
  use ExUnit.Case
  import Signs.Headway

  describe "update_sign/1" do
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

      assert update_sign(sign) == %{sign | current_content_top: %{headsign: "Chelsea", vehicle_type: "Buses"}, current_content_bottom: %{range: {1, 2}}}
    end
  end
end

defmodule FakeHeadwayEngine do
  def get_headways(stop_id) do
    {1, 2}
  end
end

defmodule FakeSignUpdater do
end
