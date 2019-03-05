defmodule Signs.Utilities.MessagesTest do
  use ExUnit.Case, async: true

  alias Signs.Utilities.Messages

  defmodule FakeAlerts do
    def max_stop_status(["suspended"], _routes), do: :suspension_closed_station
    def max_stop_status(["suspended_transfer"], _routes), do: :suspension_transfer_station
    def max_stop_status(["shuttles"], _routes), do: :shuttles_closed_station
    def max_stop_status(["closure"], _routes), do: :station_closure
    def max_stop_status(_stops, ["Green-B"]), do: :something
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

  defmodule FakeHeadways do
    def get_headways(_stop_id), do: {1, 4}
  end

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    direction_id: 0,
    headway_direction_name: "Mattapan",
    platform: nil,
    terminal?: false,
    announce_arriving?: false,
    announce_boarding?: false
  }

  @sign %Signs.Realtime{
    id: "sign_id",
    pa_ess_id: {"TEST", "x"},
    source_config: {[@src]},
    current_content_top: {@src, %Content.Message.Predictions{headsign: "Alewife", minutes: 4}},
    current_content_bottom: {@src, %Content.Message.Predictions{headsign: "Ashmont", minutes: 3}},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    alerts_engine: FakeAlerts,
    sign_updater: FakeUpdater,
    tick_bottom: 1,
    tick_top: 1,
    tick_read: 1,
    expiration_seconds: 100,
    read_period_seconds: 100
  }

  describe "get_messages" do
    test "when custom text is present, display it, overriding alerts or disabled status" do
      sign = @sign
      enabled? = false
      alert_status = :suspension
      custom_text = {"Test message", "Please ignore"}

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
               {{nil, Content.Message.Custom.new("Test message", :top)},
                {nil, Content.Message.Custom.new("Please ignore", :bottom)}}
    end

    test "when sign is disabled, it's empty" do
      sign = @sign
      enabled? = false
      alert_status = :none
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
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

      enabled? = true
      alert_status = :shuttles_transfer_station
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
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

      enabled? = true
      alert_status = :suspension_transfer_station
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
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

      enabled? = true
      alert_status = :shuttles_transfer_station
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
               {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
    end

    test "when sign is at a transfer station, but there are departure predictions it shows them" do
      sign = @sign
      enabled? = true
      alert_status = :shuttles_transfer_station
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
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
                   announce_boarding?: false,
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

    test "when sign is at a station closed by shuttles and there are no departure predictions, it says so" do
      src = %{@src | stop_id: "no_departures", direction_id: 0}

      sign = %{
        @sign
        | source_config: {[src]},
          current_content_top: {src, Content.Message.Empty.new()},
          current_content_bottom: {src, Content.Message.Empty.new()}
      }

      enabled? = true
      alert_status = :shuttles_closed_station
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
               {{nil, %Content.Message.Alert.NoService{mode: :train}},
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

      enabled? = true
      alert_status = :shuttles_closed_station
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
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
                   announce_boarding?: false,
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

    test "when sign is at a station closed due to suspension and there are no departure predictions, it says so" do
      src = %{@src | stop_id: "no_departures", direction_id: 0}

      sign = %{
        @sign
        | source_config: {[src]},
          current_content_top: {src, Content.Message.Empty.new()},
          current_content_bottom: {src, Content.Message.Empty.new()}
      }

      alert_status = :suspension_closed_station
      enabled? = true
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
               {{nil, %Content.Message.Alert.NoService{mode: :train}},
                {nil, Content.Message.Empty.new()}}
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
      enabled? = true
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
               {{nil, %Content.Message.Alert.NoService{mode: :train}},
                {nil, Content.Message.Empty.new()}}
    end

    test "when sign is at a station closed due to suspension and there are departure predictions, it shows them" do
      src = %{@src | stop_id: "1", direction_id: 0}

      sign = %{
        @sign
        | source_config: {[src]},
          current_content_top: {src, Content.Message.Empty.new()},
          current_content_bottom: {src, Content.Message.Empty.new()}
      }

      alert_status = :suspension
      enabled? = true
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
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
                   announce_boarding?: false,
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

    test "when there are predictions, puts predictions on the sign" do
      sign = @sign
      enabled? = true
      alert_status = :none
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
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
                   announce_boarding?: false,
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
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
               {{%Signs.Utilities.SourceConfig{
                   announce_arriving?: false,
                   announce_boarding?: false,
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
                   announce_boarding?: false,
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
      custom_text = nil

      assert Messages.get_messages(sign, enabled?, alert_status, custom_text) ==
               {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
    end
  end
end
