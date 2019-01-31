defmodule Signs.RealtimeTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  defmodule FakePredictions do
    def for_stop(_stop_id, _direction_id), do: []
    def stopped_at?(_stop_id), do: false
  end

  defmodule FakeHeadways do
    def get_headways(_stop_id), do: {1, 5}
  end

  defmodule FakeUpdater do
    def update_single_line(_id, _line_no, _msg, _duration, _start), do: nil
    def update_sign(_id, _top_msg, _bottom_msg, _duration, _start), do: nil
    def send_audio(_id, _audio, _priority, _timeout), do: nil
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
    pa_ess_id: {"TEST", "x"},
    source_config: {[@src]},
    current_content_top:
      {@src, %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
    current_content_bottom: {@src, %Content.Message.Headways.Bottom{range: {1, 5}}},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    sign_updater: FakeUpdater,
    tick_bottom: 1,
    tick_top: 1,
    tick_read: 1,
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

    test "decrements ticks" do
      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, @sign)
      assert sign.tick_top == 0
      assert sign.tick_bottom == 0
      assert sign.tick_read == 0
    end

    test "expires content on both lines when tick is zero" do
      sign = %{
        @sign
        | tick_top: 0,
          tick_bottom: 0
      }

      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, sign)

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

      assert sign.tick_top == 59
      assert sign.tick_bottom == 99
    end
  end
end
