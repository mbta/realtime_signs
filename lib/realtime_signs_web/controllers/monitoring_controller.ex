defmodule RealtimeSignsWeb.MonitoringController do
  require Logger
  use RealtimeSignsWeb, :controller
  import Monitoring.Uptime

  def uptime(
        conn,
        %{"time" => timestamp, "data" => %{"nodes" => nodes}} = _params
      ) do
    Logger.info("Received uptime statuses from ARINC: Node count=#{Enum.count(nodes)}")
    monitor_node_uptime(nodes, timestamp)
    send_resp(conn, 200, "")
  end

  @doc """
  Param "date" can be in either YYYY-MM-DD or YYYYMMDD formats
  """
  def run_message_log_job(conn, %{"date" => date} = _params) do
    Logger.info("Starting job to request and store message logs...")
    RealtimeSigns.MessageLogJob.get_and_store_logs(date)
    send_resp(conn, 200, "")
  end

  @doc """
  This method can be used to manually invoke a run of the job to generate a message latency report.

  Param "days" is an integer used to tell the job how many days back it should analyze
  """
  def run_message_latency_report(conn, %{"days" => days} = _params) do
    Jobs.MessageLatencyReport.generate_message_latency_report(String.to_integer(days))
    send_resp(conn, 200, "")
  end
end
