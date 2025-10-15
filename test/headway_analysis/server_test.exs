defmodule HeadwayAnalysys.ServerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import Mox

  @state %HeadwayAnalysis.Server{
    sign_id: "test_sign",
    headway_group: "test_headway_group",
    stop_ids: ["1"],
    vehicles_present: MapSet.new(["v-1"]),
    trip_lookup: %{"v-1" => "trip-1"}
  }

  setup :verify_on_exit!

  describe "update" do
    test "logs departures" do
      expect(Engine.Predictions.Mock, :revenue_vehicles, fn -> MapSet.new(["v-1"]) end)
      expect(Engine.Locations.Mock, :for_stop, fn _ -> [] end)

      expect(Engine.Config.Mock, :headway_config, fn _, _ ->
        %Engine.Config.Headway{headway_id: "x", range_low: 3, range_high: 6}
      end)

      assert capture_log([level: :info], fn ->
               HeadwayAnalysis.Server.handle_info(:update, @state)
             end) =~
               "headway_analysis_departure: sign_id=\"test_sign\" trip_id=\"trip-1\" headway_low=3 headway_high=6"
    end

    test "does not log non-revenue departures" do
      expect(Engine.Predictions.Mock, :revenue_vehicles, fn -> MapSet.new([]) end)
      expect(Engine.Locations.Mock, :for_stop, fn _ -> [] end)

      expect(Engine.Config.Mock, :headway_config, fn _, _ ->
        %Engine.Config.Headway{headway_id: "x", range_low: 3, range_high: 6}
      end)

      refute capture_log([level: :info], fn ->
               HeadwayAnalysis.Server.handle_info(:update, @state)
             end) =~ "headway_analysis_departure"
    end
  end
end
