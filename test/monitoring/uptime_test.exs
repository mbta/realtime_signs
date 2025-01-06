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
        Monitoring.Uptime.monitor_nodes(nodes, 1_234_567_890)
      end)

    assert log =~
             "node_type=scu line=line station=station device_id=UNITTESTSCU001 is_online=true"
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
        Monitoring.Uptime.monitor_nodes(nodes, 1_234_567_890)
      end)

    assert log =~
             "node_type=sign line=line station=station device_id=UNITTESTSIGN001 is_online=true sign_zone=C"
  end

  test "Logs unknown node type" do
    nodes = [
      %{
        "description" => "line:station:UNITTESTSIGN001:C",
        "is_online" => "true",
        "node_type" => "unknown_node"
      }
    ]

    log =
      capture_log([level: :info], fn ->
        Monitoring.Uptime.monitor_nodes(nodes, 1_234_567_890)
      end)

    assert log =~
             " date_time=2009-02-13 23:31:30Z tag=device_uptime node_type=unknown line=line station=station device_id=UNITTESTSIGN001 is_online=true"
  end

  test "Processes live PA connectivity" do
    nodes = [
      %{
        "Location ID" => "TEST",
        "IP Address" => "0.0.0.0",
        "Status" => "Timed out"
      }
    ]

    log =
      capture_log([level: :info], fn ->
        Monitoring.Uptime.monitor_nodes(nodes, 1_234_567_890)
      end)

    assert log =~
             "date_time=2009-02-13 23:31:30Z tag=live_pa_connectivity station_code=TEST ip_address=0.0.0.0 status=Timed_out"
  end

  test "Processes live PA application status" do
    nodes = [
      %{
        "is_online" => "true",
        "status" => "RUNNING",
        "sw_component" => "Live PA"
      }
    ]

    log =
      capture_log([level: :info], fn ->
        Monitoring.Uptime.monitor_nodes(nodes, 1_234_567_890)
      end)

    assert log =~ "node_type=Live_PA is_online=true status=RUNNING"
  end

  test "Processes headend server stats" do
    nodes = [
      %{
        "Available_D_Space" => "29.78",
        "Available_C_Space" => "29.78",
        "AvailableMemory" => "71.27",
        "Total_D_Space" => "60",
        "TotalMemory" => "127.69",
        "Total_C_Space" => "60",
        "Uptime" => "864 days, 21 hours, 55 minutes",
        "IPAddress" => "0.0.0.0"
      }
    ]

    log =
      capture_log([level: :info], fn ->
        Monitoring.Uptime.monitor_nodes(nodes, 1_234_567_890)
      end)

    assert log =~
             "date_time=2009-02-13 23:31:30Z tag=headend_server_stats ip_address=0.0.0.0 uptime_days=864 uptime_hours=21 uptime_minutes=55 total_memory=127.69 total_c_space=60 total_d_space=60 available_memory=71.27 available_c_space=29.78 available_d_space=29.78"
  end
end
