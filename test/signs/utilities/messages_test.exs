defmodule Signs.Utilities.MessagesTest do
  use ExUnit.Case, async: true

  alias Signs.Utilities.Messages

  defmodule FakePredictions do
    def for_stop("1", 0) do
      [
        %Predictions.Prediction{
          stop_id: "1",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "70093",
          seconds_until_arrival: 120,
          seconds_until_departure: 180
        },
        %Predictions.Prediction{
          stop_id: "1",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "70093",
          seconds_until_arrival: 240,
          seconds_until_departure: 300
        }
      ]
    end

    def for_stop(_stop_id, _direction_id), do: []
    def stopped_at?(_stop_id), do: false
  end

  defmodule FakeHeadways do
    def get_headways(_stop_id), do: {1, 4}
  end

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

    test "when sign is at a station closed due to suspension, it says so" do
      alert_status = :suspension
      sign = @sign
      enabled? = true

      assert Messages.get_messages(sign, enabled?, alert_status) ==
               {{nil, %Content.Message.Alert.NoService{mode: nil}},
                {nil, Content.Message.Empty.new()}}
    end

    test "when there are predictions, puts predictions on the sign" do
      sign = @sign
      enabled? = true
      alert_status = :none

      assert Messages.get_messages(sign, enabled?, alert_status) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   direction_id: 0,
                   headway_direction_name: "Mattapan",
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "1",
                   terminal?: false
                 },
                 %Content.Message.Predictions{
                   headsign: "Ashmont",
                   minutes: 2,
                   route_id: "Red",
                   stop_id: "1",
                   width: 18
                 }},
                {%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   direction_id: 0,
                   headway_direction_name: "Mattapan",
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "1",
                   terminal?: false
                 },
                 %Content.Message.Predictions{
                   headsign: "Ashmont",
                   minutes: 4,
                   route_id: "Red",
                   stop_id: "1",
                   width: 18
                 }}}
    end

    test "when there are no predictions and only one source config, puts headways on the sign" do
      sign = %{@sign | source_config: {[%{@src | stop_id: "no_preds"}]}}
      enabled? = true
      alert_status = :none

      assert Messages.get_messages(sign, enabled?, alert_status) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   direction_id: 0,
                   headway_direction_name: "Mattapan",
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "no_preds",
                   terminal?: false
                 },
                 %Content.Message.Headways.Top{
                   headsign: "Mattapan",
                   vehicle_type: :train
                 }},
                {%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   direction_id: 0,
                   headway_direction_name: "Mattapan",
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "no_preds",
                   terminal?: false
                 }, %Content.Message.Headways.Bottom{range: {1, 4}}}}
    end

    test "when there are no predictions and more than one source config, puts nothing on the sign" do
      sign = %{
        @sign
        | source_config: {[%{@src | stop_id: "no_preds"}, %{@src | stop_id: "no_preds"}]}
      }

      enabled? = true
      alert_status = :none

      assert Messages.get_messages(sign, enabled?, alert_status) ==
               {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
    end
  end
end
