defmodule Monitoring.UptimeTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  test "Processes SCU uptime data" do
    nodes = [
      %{
        "description" => "line:station:UNITTESTSCU001:SCU",
        "node_type" => "PSS",
        "is_online" => "true"
      }
    ]

    log =
      capture_log([level: :info], fn ->
        Monitoring.Uptime.monitor_device_uptime(nodes, 1_234_567_890)
      end)

    assert log =~ "device_type=scu line=line station=station scu_id=UNITTESTSCU001 is_online=true"
  end

  test "Processes sign uptime data" do
    nodes = [
      %{
        "description" => "line:station:UNITTESTSIGN001:C",
        "node_type" => "SGN",
        "is_online" => "true"
      }
    ]

    log =
      capture_log([level: :info], fn ->
        Monitoring.Uptime.monitor_device_uptime(nodes, 1_234_567_890)
      end)

    assert log =~
             "device_type=sign line=line station=station sign_id=UNITTESTSIGN001 sign_zone=C is_online=true"
  end

  test "Test unknown node type" do
    nodes = [
      %{
        "description" => "line:station:UNITTESTSIGN001:C",
        "node_type" => "ABC",
        "is_online" => "true"
      }
    ]

    log =
      capture_log([level: :warn], fn ->
        Monitoring.Uptime.monitor_device_uptime(nodes, 1_234_567_890)
      end)

    assert log =~ "Received uptime info of a node with an unknown or unspecified type"
  end

  test "Test unspecified node type" do
    nodes = [
      %{
        "description" => "line:station:UNITTESTSIGN001:C",
        "is_online" => "true"
      }
    ]

    log =
      capture_log([level: :warn], fn ->
        Monitoring.Uptime.monitor_device_uptime(nodes, 1_234_567_890)
      end)

    assert log =~ "Received uptime info of a node with an unknown or unspecified type"
  end
end
