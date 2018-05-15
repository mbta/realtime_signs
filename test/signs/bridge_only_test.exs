defmodule Signs.BridgeOnlyTest do
  use ExUnit.Case, async: true

  defmodule FakeBridgeEngine do
    def status("down") do
      {"Lowered", nil}
    end
    def status("up") do
      {"Raised", 15}
    end
    def status("notify") do
      send :bridge_only_test_fake_bridge_engine_listener, :notified
      {"Lowered", nil}
    end
    def status(_) do
      nil
    end
  end

  defmodule FakeSignUpdater do
    require Logger
    def update_sign(_id, _line, _message, _duration, _start) do
      send :bridge_only_test_fake_sign_updater_listener, :update_sign
      {:ok, :sent}
    end

    def send_audio(_pa_ess_id, msg, _priority, _timeout) do
      send :bridge_only_test_fake_sign_updater_listener, {:send_audio, msg}
      {:ok, :sent}
    end
  end

  @sign %Signs.BridgeOnly{
    id: "bridge-only-test",
    pa_ess_id: {"SSOU", "m"},
    bridge_engine: FakeBridgeEngine,
    bridge_id: "1",
    sign_updater: FakeSignUpdater,
    bridge_check_period_ms: 5 * 60 * 1000,
  }

  test "After start up, checks the bridge engine once per check period" do
    Process.register(self(), :bridge_only_test_fake_bridge_engine_listener)
    sign = %{@sign | bridge_check_period_ms: 100, bridge_id: "notify"}
    {:ok, _pid} = GenServer.start_link(Signs.BridgeOnly, sign)
    :timer.sleep(10)
    refute_received(:notified)
    :timer.sleep(150)
    assert_received(:notified)
    :timer.sleep(10)
    refute_received(:notified)
    :timer.sleep(100)
    assert_received(:notified)
  end

  test "if bridge is raised, sends canned messages, and no static text" do
    Process.register(self(), :bridge_only_test_fake_sign_updater_listener)
    sign = %{@sign | bridge_id: "up"}

    assert {:noreply, %Signs.BridgeOnly{}} = Signs.BridgeOnly.handle_info(:bridge_check, sign)
    assert_received {:send_audio, %Content.Audio.BridgeIsUp{language: :english}}
    assert_received {:send_audio, %Content.Audio.BridgeIsUp{language: :spanish}}
    refute_received :update_sign
  end

  test "if bridge is lowered, does not send canned messages" do
    Process.register(self(), :bridge_only_test_fake_sign_updater_listener)
    sign = %{@sign | bridge_id: "down"}

    assert {:noreply, %Signs.BridgeOnly{}} = Signs.BridgeOnly.handle_info(:bridge_check, sign)
    refute_received {:send_audio, _}
    refute_received :update_sign
  end
end
