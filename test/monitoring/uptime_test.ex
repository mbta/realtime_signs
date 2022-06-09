defmodule Monitoring.UptimeTest do
  use ExUnit.Case, async: true

  test "Processes SCU uptime data" do
    nodes = [
      %{
        "description" => "line:station:UNITTESTSCU001:SCU",
        "node_type" => "PSS",
        "is_online" => "true"
      }
    ]

    assert :ok = Monitoring.Uptime.monitor_device_uptime(nodes, 1_234_567_890)
  end

  test "Processes sign uptime data" do
    nodes = [
      %{
        "description" => "line:station:UNITTESTSIGN001:C",
        "node_type" => "SGN",
        "is_online" => "true"
      }
    ]

    assert :ok = Monitoring.Uptime.monitor_device_uptime(nodes, 1_234_567_890)
  end

  test "Test unknown node type" do
    nodes = [
      %{
        "description" => "line:station:UNITTESTSIGN001:C",
        "node_type" => "ABC",
        "is_online" => "true"
      }
    ]

    assert :ok = Monitoring.Uptime.monitor_device_uptime(nodes, 1_234_567_890)
  end

  test "Test unspecified node type" do
    nodes = [
      %{
        "description" => "line:station:UNITTESTSIGN001:C",
        "is_online" => "true"
      }
    ]

    assert :ok = Monitoring.Uptime.monitor_device_uptime(nodes, 1_234_567_890)
  end
end
