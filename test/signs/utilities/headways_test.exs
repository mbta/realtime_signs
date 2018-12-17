defmodule Signs.Utilities.HeadwaysTest do
  use ExUnit.Case

  defmodule FakeHeadways do
    def get_headways(_) do
      {1, 5}
    end
  end

  @sign %Signs.Realtime{
    id: "sign_id",
    pa_ess_id: {"TEST", "x"},
    source_config: {[], []},
    current_content_top: {nil, Content.Message.Empty.new()},
    current_content_bottom: {nil, Content.Message.Empty.new()},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    sign_updater: FakeUpdater,
    tick_bottom: 130,
    tick_top: 130,
    tick_read: 240,
    expiration_seconds: 130,
    read_period_seconds: 240
  }

  describe "get_messages/1" do
    test "generates blank messages when the source config has multiple sources" do
      assert Signs.Utilities.Headways.get_messages(@sign) ==
               {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}
    end

    test "generates top and bottom messages to display the headway at a stop" do
      sign = %{
        @sign
        | source_config:
            {[
               %Signs.Utilities.SourceConfig{
                 stop_id: "123",
                 headway_direction_name: "Southbound",
                 direction_id: 0,
                 platform: nil,
                 terminal?: false,
                 announce_arriving?: false,
                 multi_berth?: false
               }
             ]}
      }

      assert Signs.Utilities.Headways.get_messages(sign) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   direction_id: 0,
                   headway_direction_name: "Southbound",
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "123",
                   terminal?: false
                 }, %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   direction_id: 0,
                   headway_direction_name: "Southbound",
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "123",
                   terminal?: false
                 }, %Content.Message.Headways.Bottom{range: {1, 5}}}}
    end
  end
end
