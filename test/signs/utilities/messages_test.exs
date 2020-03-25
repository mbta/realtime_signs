defmodule Signs.Utilities.MessagesTest do
  use ExUnit.Case, async: true

  alias Signs.Utilities.Messages

  defmodule FakeAlerts do
    def max_stop_status(["suspended"], _routes), do: :suspension_closed_station
    def max_stop_status(["suspended_transfer"], _routes), do: :suspension_transfer_station
    def max_stop_status(["shuttles"], _routes), do: :shuttles_closed_station
    def max_stop_status(["closure"], _routes), do: :station_closure
    def max_stop_status(_stops, ["Green-B"]), do: :alert_along_route
    def max_stop_status(_stops, _routes), do: :none
  end

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

    def for_stop("no_departures", 0) do
      [
        %Predictions.Prediction{
          stop_id: "1",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "70093",
          seconds_until_arrival: 120
        },
        %Predictions.Prediction{
          stop_id: "1",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "70093",
          seconds_until_arrival: 240
        }
      ]
    end

    def for_stop(_stop_id, _direction_id), do: []
    def stopped_at?(_stop_id), do: false
  end

  defmodule FakeDepartures do
    @test_departure_time Timex.to_datetime(~N[2019-08-29 15:41:31], "America/New_York")

    def get_last_departure(_stop_id), do: @test_departure_time

    def test_departure_time(), do: @test_departure_time
  end

  defmodule FakeHeadways do
    def get_headways(_stop_id), do: {1, 4}
    def display_headways?(_stop_ids, _time, _buffer), do: true
  end

  defmodule FakeConfigEngine do
    def headway_config("8-11", _time) do
      %Engine.Config.Headway{headway_id: "id", range_low: 8, range_high: 11}
    end
  end

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    direction_id: 0,
    headway_destination: :mattapan,
    platform: nil,
    terminal?: false,
    announce_arriving?: false,
    announce_boarding?: false
  }

  @sign %Signs.Realtime{
    id: "sign_id",
    headway_group: "headway_group",
    text_id: {"TEST", "x"},
    audio_id: {"TEST", ["x"]},
    source_config: {[@src]},
    current_content_top: {@src, %Content.Message.Predictions{destination: :alewife, minutes: 4}},
    current_content_bottom:
      {@src, %Content.Message.Predictions{destination: :ashmont, minutes: 3}},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    last_departure_engine: FakeDepartures,
    config_engine: Engine.Config,
    alerts_engine: FakeAlerts,
    sign_updater: FakeUpdater,
    tick_bottom: 1,
    tick_top: 1,
    tick_audit: 240,
    tick_read: 1,
    expiration_seconds: 100,
    read_period_seconds: 100
  }

  describe "get_messages" do
    test "when custom text is present, display it, overriding alerts or disabled status" do
      sign = @sign
      sign_config = {:static_text, {"Test message", "Please ignore"}}
      alert_status = :suspension_closed_station

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{nil, Content.Message.Custom.new("Test message", :top)},
                {nil, Content.Message.Custom.new("Please ignore", :bottom)}}
    end

    test "when sign is disabled, it's empty" do
      sign = @sign
      sign_config = :off
      alert_status = :none

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
    end

    test "when sign is at a transfer station from a shuttle, and there are no predictions it's empty" do
      src = %{@src | stop_id: "no_predictions", direction_id: 1}

      sign = %{
        @sign
        | source_config: {[src]},
          current_content_top: {src, Content.Message.Empty.new()},
          current_content_bottom: {src, Content.Message.Empty.new()}
      }

      sign_config = :auto
      alert_status = :shuttles_transfer_station

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
    end

    test "when sign is at a transfer station from a suspension, and there are no predictions it's empty" do
      src = %{@src | stop_id: "no_predictions", direction_id: 1}

      sign = %{
        @sign
        | source_config: {[src]},
          current_content_top: {src, Content.Message.Empty.new()},
          current_content_bottom: {src, Content.Message.Empty.new()}
      }

      sign_config = :auto
      alert_status = :suspension_transfer_station

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
    end

    test "when sign is at a transfer station, and there are no departure predictions it's empty" do
      src = %{@src | stop_id: "no_departures", direction_id: 0}

      sign = %{
        @sign
        | source_config: {[src]},
          current_content_top: {src, Content.Message.Empty.new()},
          current_content_bottom: {src, Content.Message.Empty.new()}
      }

      sign_config = :auto
      alert_status = :shuttles_transfer_station

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
    end

    test "when sign is at a transfer station, but there are departure predictions it shows them" do
      sign = @sign
      sign_config = :auto
      alert_status = :shuttles_transfer_station

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
                   direction_id: 0,
                   headway_destination: :mattapan,
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "1",
                   terminal?: false
                 },
                 %Content.Message.Predictions{
                   destination: :ashmont,
                   minutes: 2,
                   route_id: "Red",
                   stop_id: "1",
                   width: 18
                 }},
                {%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
                   direction_id: 0,
                   headway_destination: :mattapan,
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "1",
                   terminal?: false
                 },
                 %Content.Message.Predictions{
                   destination: :ashmont,
                   minutes: 4,
                   route_id: "Red",
                   stop_id: "1",
                   width: 18
                 }}}
    end

    test "when sign is at a station closed by shuttles and there are no departure predictions, it says so" do
      src = %{@src | stop_id: "no_departures", direction_id: 0}

      sign = %{
        @sign
        | source_config: {[src]},
          current_content_top: {src, Content.Message.Empty.new()},
          current_content_bottom: {src, Content.Message.Empty.new()}
      }

      sign_config = :auto
      alert_status = :shuttles_closed_station

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{nil, %Content.Message.Alert.NoService{}},
                {nil, %Content.Message.Alert.UseShuttleBus{}}}
    end

    test "when sign is at a station closed by shuttles and there are departure predictions, it shows them" do
      src = %{@src | stop_id: "1", direction_id: 0}

      sign = %{
        @sign
        | source_config: {[src]},
          current_content_top: {src, Content.Message.Empty.new()},
          current_content_bottom: {src, Content.Message.Empty.new()}
      }

      sign_config = :auto
      alert_status = :shuttles_closed_station

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
                   direction_id: 0,
                   headway_destination: :mattapan,
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "1",
                   terminal?: false
                 },
                 %Content.Message.Predictions{
                   destination: :ashmont,
                   minutes: 2,
                   route_id: "Red",
                   stop_id: "1",
                   width: 18
                 }},
                {%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
                   direction_id: 0,
                   headway_destination: :mattapan,
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "1",
                   terminal?: false
                 },
                 %Content.Message.Predictions{
                   destination: :ashmont,
                   minutes: 4,
                   route_id: "Red",
                   stop_id: "1",
                   width: 18
                 }}}
    end

    test "when sign is at a station closed due to suspension and there are no departure predictions, it says so" do
      src = %{@src | stop_id: "no_departures", direction_id: 0}

      sign = %{
        @sign
        | source_config: {[src]},
          current_content_top: {src, Content.Message.Empty.new()},
          current_content_bottom: {src, Content.Message.Empty.new()}
      }

      alert_status = :suspension_closed_station
      sign_config = :auto

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{nil, %Content.Message.Alert.NoService{}}, {nil, Content.Message.Empty.new()}}
    end

    test "when sign is at a closed station and there are no departure predictions, it says so" do
      src = %{@src | stop_id: "no_departures", direction_id: 0}

      sign = %{
        @sign
        | source_config: {[src]},
          current_content_top: {src, Content.Message.Empty.new()},
          current_content_bottom: {src, Content.Message.Empty.new()}
      }

      alert_status = :station_closure
      sign_config = :auto

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{nil, %Content.Message.Alert.NoService{}}, {nil, Content.Message.Empty.new()}}
    end

    test "when sign is at a station closed due to suspension and there are departure predictions, it shows them" do
      src = %{@src | stop_id: "1", direction_id: 0}

      sign = %{
        @sign
        | source_config: {[src]},
          current_content_top: {src, Content.Message.Empty.new()},
          current_content_bottom: {src, Content.Message.Empty.new()}
      }

      alert_status = :suspension_closed_station
      sign_config = :auto

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
                   direction_id: 0,
                   headway_destination: :mattapan,
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "1",
                   terminal?: false
                 },
                 %Content.Message.Predictions{
                   destination: :ashmont,
                   minutes: 2,
                   route_id: "Red",
                   stop_id: "1",
                   width: 18
                 }},
                {%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
                   direction_id: 0,
                   headway_destination: :mattapan,
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "1",
                   terminal?: false
                 },
                 %Content.Message.Predictions{
                   destination: :ashmont,
                   minutes: 4,
                   route_id: "Red",
                   stop_id: "1",
                   width: 18
                 }}}
    end

    test "when there are predictions, puts predictions on the sign" do
      sign = @sign
      sign_config = :auto
      alert_status = :none

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
                   direction_id: 0,
                   headway_destination: :mattapan,
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "1",
                   terminal?: false
                 },
                 %Content.Message.Predictions{
                   destination: :ashmont,
                   minutes: 2,
                   route_id: "Red",
                   stop_id: "1",
                   width: 18
                 }},
                {%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
                   direction_id: 0,
                   headway_destination: :mattapan,
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "1",
                   terminal?: false
                 },
                 %Content.Message.Predictions{
                   destination: :ashmont,
                   minutes: 4,
                   route_id: "Red",
                   stop_id: "1",
                   width: 18
                 }}}
    end

    test "when there are no predictions and only one source config, puts headways on the sign" do
      sign = %{
        @sign
        | source_config: {[%{@src | stop_id: "no_preds"}]},
          config_engine: FakeConfigEngine,
          headway_group: "8-11"
      }

      sign_config = :auto
      alert_status = :none

      current_time = Timex.shift(FakeDepartures.test_departure_time(), minutes: 5)

      assert Messages.get_messages(sign, sign_config, current_time, alert_status) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
                   direction_id: 0,
                   headway_destination: :mattapan,
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "no_preds",
                   terminal?: false
                 },
                 %Content.Message.Headways.Top{
                   destination: :mattapan,
                   vehicle_type: :train
                 }},
                {%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
                   direction_id: 0,
                   headway_destination: :mattapan,
                   multi_berth?: false,
                   platform: nil,
                   routes: nil,
                   stop_id: "no_preds",
                   terminal?: false
                 },
                 %Content.Message.Headways.Bottom{
                   range: {8, 11},
                   prev_departure_mins: nil
                 }}}
    end

    test "when there are no predictions and more than one source config, puts nothing on the sign" do
      sign = %{
        @sign
        | source_config: {[%{@src | stop_id: "no_preds"}, %{@src | stop_id: "no_preds"}]}
      }

      sign_config = :auto
      alert_status = :none

      assert Messages.get_messages(sign, sign_config, Timex.now(), alert_status) ==
               {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
    end

    test "when sign is forced into headway mode but no alerts are present, displays headways" do
      sign = %{@sign | config_engine: FakeConfigEngine, headway_group: "8-11"}
      sign_config = :headway
      alert_status = :none

      assert {{_,
               %Content.Message.Headways.Top{
                 destination: :mattapan,
                 vehicle_type: :train
               }},
              {_, %Content.Message.Headways.Bottom{range: {8, 11}}}} =
               Messages.get_messages(sign, sign_config, Timex.now(), alert_status)
    end

    test "when sign is forced into headway mode but alerts are present, alert takes precedence" do
      sign = @sign
      sign_config = :headway
      alert_status = :station_closure

      assert {{_, %Content.Message.Alert.NoService{}}, {_, %Content.Message.Empty{}}} =
               Messages.get_messages(sign, sign_config, Timex.now(), alert_status)
    end
  end
end
