defmodule RealtimeSignsWeb.MonitoringController do
  require Logger
  use RealtimeSignsWeb, :controller
  alias Monitoring.Headend
  alias Monitoring.Uptime

  def uptime(
        conn,
        %{"time" => timestamp, "data" => %{"nodes" => nodes}} = _params
      ) do
    Logger.info("Received uptime statuses from ARINC: Node count=#{Enum.count(nodes)}")
    Uptime.monitor_node_uptime(nodes, timestamp)
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

  Param "start_date" is where the job starts and should be in iso8601 format (YYYY-MM-DD)
  Param "days" is an integer used to tell the job how many days back it should analyze
  """
  def run_message_latency_report(conn, %{"start_date" => start_date, "days" => days} = _params) do
    Logger.info(
      "Beginning manual run of message latency report starting from #{start_date} going back #{days} days"
    )

    Jobs.MessageLatencyReport.generate_message_latency_reports(
      Date.from_iso8601!(start_date),
      String.to_integer(days)
    )

    send_resp(conn, 200, "")
  end

  def update_active_headend(conn, %{"active_ip" => active_ip} = _params) do
    case Headend.update_active_headend_ip(active_ip) do
      {:ok, _} ->
        send_resp(conn, 200, "ok")

      {:bad_request, message} ->
        send_resp(conn, 400, message)

      {:error, _} ->
        send_resp(conn, 500, "Internal server error")
    end
  end
end
