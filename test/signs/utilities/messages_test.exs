defmodule Signs.Utilities.MessagesTest do
  use ExUnit.Case, async: true

  alias Signs.Utilities.Messages

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    direction_id: 0,
    headway_direction_name: "Mattapan",
    platform: nil,
    terminal?: false,
    announce_arriving?: false
  }

  @sign %Signs.Realtime{
    id: "sign_id",
    pa_ess_id: {"TEST", "x"},
    source_config: {[@src]},
    current_content_top: {@src, %Content.Message.Predictions{headsign: "Alewife", minutes: 4}},
    current_content_bottom: {@src, %Content.Message.Predictions{headsign: "Ashmont", minutes: 3}},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    sign_updater: FakeUpdater,
    tick_bottom: 1,
    tick_top: 1,
    tick_read: 1,
    expiration_seconds: 100,
    read_period_seconds: 100
  }

  describe "get_messages" do
    test "when sign is disabled, it's empty" do
      sign = @sign
      enabled? = false
      alert_status = :none

      assert Messages.get_messages(sign, enabled?, alert_status) ==
               {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
    end

    test "when sign is at a transfer station, it's empty" do
      sign = @sign
      enabled? = true
      alert_status = :shuttles_transfer_station

      assert Messages.get_messages(sign, enabled?, alert_status) ==
               {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
    end

    test "when sign is at a station closed by shuttles, it says so" do
      sign = @sign
      enabled? = true
      alert_status = :shuttles_closed_station

      assert Messages.get_messages(sign, enabled?, alert_status) ==
               {{nil, %Content.Message.Alert.NoService{}},
                {nil, %Content.Message.Alert.UseShuttleBus{}}}
    end
  end
end
