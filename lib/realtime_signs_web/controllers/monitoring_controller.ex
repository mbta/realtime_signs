defmodule RealtimeSignsWeb.MonitoringController do
  require Logger
  use RealtimeSignsWeb, :controller
  import Monitoring.Uptime

  def uptime(
        conn,
        %{"time" => timestamp, "data" => %{"nodes" => nodes}} = _params
      ) do
    Logger.info("Received device statuses from ARINC: Device count=#{Enum.count(nodes)}")
    monitor_device_uptime(nodes, timestamp)
    send_resp(conn, 200, "")
  end
end
