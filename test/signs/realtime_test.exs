defmodule Signs.RealtimeTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  defmodule FakePredictions do
    def for_stop(_stop_id, _direction_id), do: []
    def stopped_at?(_stop_id), do: false
  end

  defmodule FakeUpdater do
    def update_single_line(_id, _line_no, _msg, _duration, _start), do: nil
    def update_sign(_id, _top_msg, _bottom_msg, _duration, _start), do: nil
    def send_audio(_id, _audio, _priority, _timeout), do: nil
  end

  @sign %Signs.Realtime{
    id: "sign_id",
    pa_ess_id: {"TEST", "x"},
    source_config: {[], []},
    current_content_top: {nil, Content.Message.Empty.new()},
    current_content_bottom: {nil, Content.Message.Empty.new()},
    prediction_engine: FakePredictions,
    sign_updater: FakeUpdater,
    tick_bottom: 1,
    tick_top: 1,
    tick_read: 1,
    expiration_seconds: 100,
    read_period_seconds: 100,
  }

  describe "run loop" do
    test "starts up and logs unknown messages" do
      assert {:ok, pid} = GenServer.start_link(Signs.Realtime, @sign)

      log = capture_log [level: :warn], fn ->
        send(pid, :foo)
        :timer.sleep(50)
      end

      assert Process.alive?(pid)
      assert log =~ "unknown_message"
    end

    test "decrements ticks" do
      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, @sign)
      assert sign.tick_top == 0
      assert sign.tick_bottom == 0
      assert sign.tick_read == 0
    end

    test "expires content when tick is zero" do
      sign = %{@sign |
        current_content_top: {%{}, :to_be_expired},
        tick_top: 0,
        current_content_bottom: {%{}, :to_be_expired},
        tick_bottom: 0,
      }

      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, sign)

      assert sign.current_content_top == {nil, Content.Message.Empty.new()}
      assert sign.tick_top == 99
      assert sign.current_content_bottom == {nil, Content.Message.Empty.new()}
      assert sign.tick_bottom == 99
    end
  end
end
