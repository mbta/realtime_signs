defmodule Engine.HealthTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  test "logs pool stats" do
    {:ok, _pid} = Engine.Health.start_link(name: :health_test, period_ms: 500)

    log =
      capture_log(fn ->
        Process.sleep(600)
      end)

    assert log =~ "event=pool_info"
  end
end
