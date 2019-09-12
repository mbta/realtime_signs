defmodule Signs.RealtimeTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Content.Message.Headways.Top, as: HT
  alias Content.Message.Headways.Bottom, as: HB

  defmodule FakePredictions do
    def for_stop(_stop_id, _direction_id), do: []
    def stopped_at?(_stop_id), do: false
  end

  defmodule FakePassthroughPredictions do
    def for_stop("1", 0) do
      [
        %Predictions.Prediction{
          stop_id: "1",
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
    end

    def for_stop(_stop_id, _direction_id), do: []
  end

  defmodule FakeDepartureEngine do
    @test_departure_time nil

    def get_last_departure(_) do
      @test_departure_time
    end

    def test_departure_time() do
      @test_departure_time
    end
  end

  defmodule FakeHeadways do
    def get_headways(_stop_id), do: {1, 5}
  end

  defmodule FakeUpdater do
    def update_single_line(id, line_no, msg, duration, start) do
      send(self(), {:update_single_line, id, line_no, msg, duration, start})
    end

    def update_sign(id, top_msg, bottom_msg, duration, start) do
      send(self(), {:update_sign, id, top_msg, bottom_msg, duration, start})
    end

    def send_audio(id, audio, priority, timeout) do
      send(self(), {:send_audio, id, audio, priority, timeout})
    end
  end

  defmodule FakeAlerts do
    def max_stop_status(["suspended"], _routes), do: :suspension_closed_station
    def max_stop_status(["suspended_transfer"], _routes), do: :suspension_transfer_station
    def max_stop_status(["shuttles"], _routes), do: :shuttles_closed_station
    def max_stop_status(["closure"], _routes), do: :station_closure
    def max_stop_status(_stops, ["Green-B"]), do: :alert_along_route
    def max_stop_status(_stops, _routes), do: :none
  end

  defmodule FakeBridge do
    def status(_bridge_id), do: {"Raised", 5}
  end

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    headway_direction_name: "Southbound",
    direction_id: 0,
    platform: nil,
    terminal?: false,
    announce_arriving?: false,
    announce_boarding?: false
  }

  @sign %Signs.Realtime{
    id: "sign_id",
    text_id: {"TEST", "x"},
    audio_id: {"TEST", ["x"]},
    source_config: {[@src]},
    current_content_top: {@src, %HT{headsign: "Southbound", vehicle_type: :train}},
    current_content_bottom: {@src, %HB{range: {1, 5}, prev_departure_mins: nil}},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    last_departure_engine: FakeDepartureEngine,
    alerts_engine: FakeAlerts,
    bridge_engine: nil,
    sign_updater: FakeUpdater,
    tick_bottom: 1,
    tick_top: 1,
    tick_read: 1,
    tick_audit: 1,
    expiration_seconds: 100,
    read_period_seconds: 100
  }

  describe "run loop" do
    test "starts up and logs unknown messages" do
      assert {:ok, pid} = GenServer.start_link(Signs.Realtime, @sign)

      log =
        capture_log([level: :warn], fn ->
          send(pid, :foo)
          :timer.sleep(50)
        end)

      assert Process.alive?(pid)
      assert log =~ "unknown_message"
    end

    test "decrements ticks and doesn't send audio or text when sign is not expired" do
      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, @sign)
      refute_received({:send_audio, _, _, _, _})
      refute_received({:update_single_line, _, _, _, _, _})
      refute_received({:update_sign, _, _, _, _, _})
      assert sign.tick_top == 0
      assert sign.tick_bottom == 0
      assert sign.tick_read == 0
    end

    test "decrements ticks and doesn't send audio or text when sign is not expired, bridge case" do
      assert {:noreply, sign} =
               Signs.Realtime.handle_info(:run_loop, %{
                 @sign
                 | bridge_engine: FakeBridge,
                   bridge_id: "1"
               })

      refute_received({:send_audio, _, _, _, _})
      refute_received({:update_single_line, _, _, _, _, _})
      refute_received({:update_sign, _, _, _, _, _})
      assert sign.tick_top == 0
      assert sign.tick_bottom == 0
      assert sign.tick_read == 0
      assert sign.tick_audit == 0
    end

    test "expires content on both lines when tick is zero" do
      sign = %{
        @sign
        | tick_top: 0,
          tick_bottom: 0
      }

      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, sign)

      assert_received(
        {:update_sign, _id, %HT{headsign: "Southbound", vehicle_type: :train}, %HB{range: {1, 5}},
         _dur, _start}
      )

      refute_received({:send_audio, _, _, _, _})

      assert sign.tick_top == 99
      assert sign.tick_bottom == 99
    end

    test "expires content on top when tick is zero" do
      sign = %{
        @sign
        | tick_top: 0,
          tick_bottom: 60
      }

      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, sign)

      assert_received(
        {:update_single_line, _id, "1", %HT{headsign: "Southbound", vehicle_type: :train}, _dur,
         _start}
      )

      refute_received({:send_audio, _, _, _, _})

      assert sign.tick_top == 99
      assert sign.tick_bottom == 59
    end

    test "expires content on bottom when tick is zero" do
      sign = %{
        @sign
        | tick_top: 60,
          tick_bottom: 0
      }

      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, sign)

      assert_received({:update_single_line, _id, "2", %HB{range: {1, 5}}, _dur, _start})

      refute_received({:send_audio, _, _, _, _})

      assert sign.tick_top == 59
      assert sign.tick_bottom == 99
    end

    test "announces train passing through station" do
      sign = %{
        @sign
        | prediction_engine: FakePassthroughPredictions
      }

      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, sign)
      assert sign.announced_passthroughs == ["123"]
      assert_received({:send_audio, _, %Content.Audio.Passthrough{}, _, _})
    end
  end

  describe "decrement_ticks/1" do
    test "decrements all the ticks when all of them dont need to be reset" do
      sign = %{
        @sign
        | tick_top: 100,
          tick_bottom: 100,
          tick_read: 100
      }

      sign = Signs.Realtime.decrement_ticks(sign)

      assert sign.tick_top == 99
      assert sign.tick_bottom == 99
      assert sign.tick_read == 99
    end
  end

  describe "log_headway_accuracy/1" do
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
        | current_content_bottom: {@src, %HB{range: {5, nil}, prev_departure_mins: 4}},
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
        | current_content_bottom: {@src, %HB{range: {5, nil}, prev_departure_mins: 6}},
          tick_audit: 0
      }

      log =
        capture_log([level: :info], fn ->
          Signs.Realtime.log_headway_accuracy(sign)
        end)

      assert log =~ "in_range=false"
    end
  end
end
