defmodule Signs.RealtimeTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  import Mox

  alias Content.Message.Headways.Top, as: HT
  alias Content.Message.Headways.Bottom, as: HB

  defmodule FakeHeadways do
    def get_headways(_stop_id), do: {1, 5}
    def display_headways?(_stop_ids, _time, _buffer), do: true
  end

  @headway_config %Engine.Config.Headway{headway_id: "id", range_low: 11, range_high: 13}

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    direction_id: 0,
    platform: nil,
    terminal?: false,
    announce_arriving?: false,
    announce_boarding?: false
  }

  @fake_time DateTime.new!(~D[2023-01-01], ~T[12:00:00], "America/New_York")
  def fake_time_fn, do: @fake_time

  @sign %Signs.Realtime{
    id: "sign_id",
    text_id: {"TEST", "x"},
    audio_id: {"TEST", ["x"]},
    source_config: %{
      sources: [@src],
      headway_group: "headway_group",
      headway_destination: :southbound
    },
    current_content_top: %HT{destination: :southbound, vehicle_type: :train},
    current_content_bottom: %HB{range: {11, 13}},
    prediction_engine: Engine.Predictions.Mock,
    headway_engine: FakeHeadways,
    last_departure_engine: nil,
    config_engine: Engine.Config.Mock,
    alerts_engine: Engine.Alerts.Mock,
    current_time_fn: &Signs.RealtimeTest.fake_time_fn/0,
    sign_updater: PaEss.Updater.Mock,
    last_update: @fake_time,
    tick_read: 1,
    tick_audit: 1,
    read_period_seconds: 100
  }

  @predictions [
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

  @no_departures_predictions [
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

  @no_service_audio {:canned, {"107", ["861", "21000", "864", "21000", "863"], :audio}}

  setup :verify_on_exit!

  describe "run loop" do
    setup do
      stub(Engine.Config.Mock, :sign_config, fn _ -> :auto end)
      stub(Engine.Config.Mock, :headway_config, fn _, _ -> @headway_config end)
      stub(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :none end)
      stub(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)
      :ok
    end

    test "starts up and logs unknown messages" do
      assert {:ok, pid} = GenServer.start_link(Signs.Realtime, @sign)

      log =
        capture_log([level: :warn], fn ->
          send(pid, :foo)
          Process.sleep(50)
        end)

      assert Process.alive?(pid)
      assert log =~ "unknown_message"
    end

    test "decrements ticks and doesn't send audio or text when sign is not expired" do
      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, @sign)
      assert sign.tick_read == 0
    end

    test "refreshes content when expired" do
      expect_messages({"Southbound trains", "Every 11 to 13 min"})
      sign = %{@sign | last_update: Timex.shift(@fake_time, seconds: -200)}
      Signs.Realtime.handle_info(:run_loop, sign)
    end

    test "announces train passing through station" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          %Predictions.Prediction{
            stop_id: "passthrough_audio",
            direction_id: 0,
            route_id: "Red",
            stopped?: false,
            stops_away: 4,
            destination_stop_id: "70105",
            seconds_until_arrival: nil,
            seconds_until_departure: nil,
            seconds_until_passthrough: 30,
            trip_id: "123"
          }
        ]
      end)

      expect_audios([{:canned, {"103", ["32118"], :audio_visual}}])
      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, @sign)
      assert sign.announced_passthroughs == ["123"]
    end

    test "when custom text is present, display it, overriding alerts" do
      expect(Engine.Config.Mock, :sign_config, fn _ -> {:static_text, {"custom", "message"}} end)
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :suspension_closed_station end)
      expect_messages({"custom", "message"})
      expect_audios([{:ad_hoc, {"custom message", :audio}}])
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is disabled, it's empty" do
      expect(Engine.Config.Mock, :sign_config, fn _ -> :off end)
      expect_messages({"", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a transfer station from a shuttle, and there are no predictions it's empty" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :shuttles_transfer_station end)
      expect_messages({"", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a transfer station from a suspension, and there are no predictions it's empty" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :suspension_transfer_station end)
      expect_messages({"", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a transfer station, and there are no departure predictions it's empty" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :shuttles_transfer_station end)
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> @no_departures_predictions end)
      expect_messages({"", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a transfer station, but there are departure predictions it shows them" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :shuttles_transfer_station end)
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> @predictions end)
      expect_messages({"Ashmont      2 min", "Ashmont      4 min"})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a station closed by shuttles and there are no departure predictions, it says so" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :shuttles_closed_station end)
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> @no_departures_predictions end)
      expect_messages({"No train service", "Use shuttle bus"})
      expect_audios([{:canned, {"199", ["864"], :audio}}])
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a station closed and there are no departure predictions, but shuttles do not run at this station" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :shuttles_closed_station end)
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> @no_departures_predictions end)
      expect_messages({"No train service", ""})
      expect_audios([@no_service_audio])
      Signs.Realtime.handle_info(:run_loop, %{@sign | uses_shuttles: false})
    end

    test "when sign is at a station closed by shuttles and there are departure predictions, it shows them" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :shuttles_closed_station end)
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> @predictions end)
      expect_messages({"Ashmont      2 min", "Ashmont      4 min"})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a station closed due to suspension and there are no departure predictions, it says so" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :suspension_closed_station end)
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> @no_departures_predictions end)
      expect_messages({"No train service", ""})
      expect_audios([@no_service_audio])
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a closed station and there are no departure predictions, it says so" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :station_closure end)
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> @no_departures_predictions end)
      expect_messages({"No train service", ""})
      expect_audios([@no_service_audio])
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a station closed due to suspension and there are departure predictions, it shows them" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :suspension_closed_station end)
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> @predictions end)
      expect_messages({"Ashmont      2 min", "Ashmont      4 min"})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when there are predictions, puts predictions on the sign" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> @predictions end)
      expect_messages({"Ashmont      2 min", "Ashmont      4 min"})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when there are no predictions and only one source config, puts headways on the sign" do
      expect(Engine.Config.Mock, :headway_config, fn _, _ ->
        %{@headway_config | range_high: 14}
      end)

      expect_messages({"Southbound trains", "Every 11 to 14 min"})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is forced into headway mode but no alerts are present, displays headways" do
      expect(Engine.Config.Mock, :sign_config, fn _ -> :headway end)

      expect(Engine.Config.Mock, :headway_config, fn _, _ ->
        %{@headway_config | range_high: 14}
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> @predictions end)
      expect_messages({"Southbound trains", "Every 11 to 14 min"})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is forced into headway mode but alerts are present, alert takes precedence" do
      expect(Engine.Config.Mock, :sign_config, fn _ -> :headway end)
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> @predictions end)
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :station_closure end)
      expect_messages({"No train service", ""})
      expect_audios([@no_service_audio])
      Signs.Realtime.handle_info(:run_loop, @sign)
    end
  end

  describe "decrement_ticks/1" do
    test "decrements all the ticks when all of them dont need to be reset" do
      sign = %{
        @sign
        | tick_read: 100
      }

      sign = Signs.Realtime.decrement_ticks(sign)

      assert sign.tick_read == 99
    end
  end

  describe "log_headway_accuracy/1" do
    test "does not log the headway accuracy check when the last departure is nil" do
      sign = %{
        @sign
        | current_content_bottom: {@src, %HB{range: {1, 5}, prev_departure_mins: nil}},
          tick_audit: 1
      }

      log =
        capture_log([level: :info], fn ->
          Signs.Realtime.log_headway_accuracy(sign)
        end)

      assert log == ""
    end

    test "does not log the headway accuracy check when the tick_audit is not 0" do
      sign = %{
        @sign
        | current_content_bottom: {@src, %HB{range: {1, 5}, prev_departure_mins: 2}},
          tick_audit: 1
      }

      log =
        capture_log([level: :info], fn ->
          Signs.Realtime.log_headway_accuracy(sign)
        end)

      assert log == ""
    end

    test "sets tick_audit back to 60 when it has nothign to log but the tick_audit is 0" do
      sign = %{
        @sign
        | current_content_bottom: {@src, %HB{range: {1, 5}, prev_departure_mins: nil}},
          tick_audit: 0
      }

      sign = Signs.Realtime.log_headway_accuracy(sign)

      assert sign.tick_audit == 60
    end

    test "sets tick_audit back to 60 when it logs" do
      sign = %{
        @sign
        | current_content_bottom: {@src, %HB{range: {1, 5}, prev_departure_mins: 2}},
          tick_audit: 0
      }

      sign = Signs.Realtime.log_headway_accuracy(sign)

      assert sign.tick_audit == 60
    end

    test "logs stop id, headway, and last departure" do
      sign = %{
        @sign
        | current_content_bottom: {@src, %HB{range: {1, 5}, prev_departure_mins: 2}},
          tick_audit: 0
      }

      log =
        capture_log([level: :info], fn ->
          Signs.Realtime.log_headway_accuracy(sign)
        end)

      assert log =~ "stop_id=1"
      assert log =~ "headway_max=5"
      assert log =~ "last_departure=2"
    end

    test "logs the headway accuracy check when the tick_audit is 0" do
      sign = %{
        @sign
        | current_content_bottom: {@src, %HB{range: {1, 5}, prev_departure_mins: 2}},
          tick_audit: 0
      }

      log =
        capture_log([level: :info], fn ->
          Signs.Realtime.log_headway_accuracy(sign)
        end)

      assert log =~ "headway_accuracy_check"
    end

    test "evaluates the headway as accurate if the last departure is less than the max of the range" do
      sign = %{
        @sign
        | current_content_bottom: {@src, %HB{range: {1, 5}, prev_departure_mins: 2}},
          tick_audit: 0
      }

      log =
        capture_log([level: :info], fn ->
          Signs.Realtime.log_headway_accuracy(sign)
        end)

      assert log =~ "in_range=true"
    end

    test "evaluates the headway as inaccurate if the last departure is greater than the max of the range" do
      sign = %{
        @sign
        | current_content_bottom: {@src, %HB{range: {1, 5}, prev_departure_mins: 6}},
          tick_audit: 0
      }

      log =
        capture_log([level: :info], fn ->
          Signs.Realtime.log_headway_accuracy(sign)
        end)

      assert log =~ "in_range=false"
    end

    test "evaluates the headway as accurate if the last departure is less than the only number in the range" do
      sign = %{
        @sign
        | current_content_bottom: {@src, %HB{range: {:up_to, 5}, prev_departure_mins: 4}},
          tick_audit: 0
      }

      log =
        capture_log([level: :info], fn ->
          Signs.Realtime.log_headway_accuracy(sign)
        end)

      assert log =~ "in_range=true"
    end

    test "evaluates the headway as inaccurate if the last departure is greater than the only number in the range" do
      sign = %{
        @sign
        | current_content_bottom: {@src, %HB{range: {:up_to, 5}, prev_departure_mins: 6}},
          tick_audit: 0
      }

      log =
        capture_log([level: :info], fn ->
          Signs.Realtime.log_headway_accuracy(sign)
        end)

      assert log =~ "in_range=false"
    end
  end

  defp expect_messages(messages) do
    expect(PaEss.Updater.Mock, :update_sign, fn {"TEST", "x"}, top, bottom, 145, :now, _sign_id ->
      assert {Content.Message.to_string(top), Content.Message.to_string(bottom)} == messages
      :ok
    end)
  end

  defp expect_audios(audios) do
    expect(PaEss.Updater.Mock, :send_audio, fn {"TEST", ["x"]}, list, 5, 60, _sign_id ->
      assert Enum.map(list, &Content.Audio.to_params(&1)) == audios
      :ok
    end)
  end
end
