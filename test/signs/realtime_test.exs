defmodule Signs.RealtimeTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Content.Message.Headways.Top, as: HT
  alias Content.Message.Headways.Bottom, as: HB

  defmodule FakePredictions do
    def for_stop(_stop_id, _direction_id), do: []
    def stopped_at?(_stop_id), do: false
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
    current_content_top: {@src, %HT{headsign: "Southbound", vehicle_type: :train}},
    current_content_bottom: {@src, %HB{range: {1, 5}}},
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

    test "decrements ticks and doesn't send audio or text when sign is not expired" do
      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, @sign)
      refute_received({:send_audio, _, _, _, _})
      refute_received({:update_single_line, _, _, _, _, _})
      refute_received({:update_sign, _, _, _, _, _})
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
  end
end
