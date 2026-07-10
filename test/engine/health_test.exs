defmodule Engine.HealthTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import Mox

  setup :verify_on_exit!

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
