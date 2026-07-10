defmodule Engine.HealthTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import Mox

  setup :verify_on_exit!

  test "logs pool stats" do
    {:ok, _pid} = Engine.Health.start_link(period_ms: 50)

    log =
      capture_log(fn ->
        Process.sleep(60)
      end)

    assert log =~ "event=pool_info"
  end

  test "logs metrics of main app tree" do
    log =
      capture_log([level: :info], fn ->
        Engine.Health.handle_info(:process_health, nil)
      end)

    assert log =~ ~r/
      realtime_signs_process_health
      \ name=Engine.Config
      \ supervisor=RealtimeSigns
      \ memory=\d+
      \ binary_memory=\d+
      \ heap_size=\d+
      \ total_heap_size=\d+
      \ message_queue_len=\d+
      \ reductions=\d+
    /x
  end
end
