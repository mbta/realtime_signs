defmodule Engine.HealthTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import Mox
  require Logger

  setup :verify_on_exit!

  test "logs pool stats" do
    {:ok, _pid} = Engine.Health.start_link(period_ms: 500)

    log =
      capture_log(fn ->
        Process.sleep(600)
      end)

    assert log =~ "event=pool_info"
  end

  test "restarts after 5 consecutive failed network checks" do
    test_pid = self()

    Engine.NetworkCheck.Mock
    |> expect(:check, 1, fn -> :ok end)
    |> expect(:check, 5, fn -> :error end)
    |> stub(:check, fn ->
      send(test_pid, :all_checks_done)
      :ok
    end)

    {:ok, health_pid} =
      Engine.Health.start_link(
        period_ms: 15,
        network_check_mod: Engine.NetworkCheck.Mock,
        restart_fn: fn -> send(test_pid, :restarting) end
      )

    allow(Engine.NetworkCheck.Mock, test_pid, health_pid)

    assert_receive :restarting, 150
  end

  test "does not restart after 5 non-consecutive failed network checks" do
    test_pid = self()

    Engine.NetworkCheck.Mock
    |> expect(:check, 1, fn -> :ok end)
    |> expect(:check, 4, fn -> :error end)
    |> expect(:check, 1, fn -> :ok end)
    |> expect(:check, 1, fn -> :error end)
    |> stub(:check, fn ->
      send(test_pid, :all_checks_done)
      :ok
    end)

    {:ok, health_pid} =
      Engine.Health.start_link(
        period_ms: 15,
        network_check_mod: Engine.NetworkCheck.Mock,
        restart_fn: fn -> send(test_pid, :restarting) end
      )

    allow(Engine.NetworkCheck.Mock, test_pid, health_pid)

    assert_receive :all_checks_done, 150
    refute_received :restarting
  end

  test "handles unknown messages like :ssl_closed" do
    {:ok, pid} = Engine.Health.start_link()

    log =
      capture_log(fn ->
        send(pid, :ssl_closed)
      end)

    assert log =~ "unknown_message"
    assert Process.alive?(pid)
  end

  test "logs metrics of main app tree" do
    log =
      capture_log([level: :info], fn ->
        Engine.Health.handle_info({:process_health, 1_000}, %Engine.Health{})
      end)

    assert log =~ ~r/
      realtime_signs_process_health
      \ name="Engine.Config"
      \ supervisor="RealtimeSigns"
      \ memory=\d+
      \ binary_memory=\d+
      \ heap_size=\d+
      \ total_heap_size=\d+
      \ message_queue_len=\d+
      \ reductions=\d+
    /x
  end

  describe "restart_noop/0" do
    test "does nothing and returns :ok" do
      assert Engine.Health.restart_noop() == :ok
    end
  end
end
