defmodule RealtimeSignsWeb.MonitoringController do
  require Logger
  use RealtimeSignsWeb, :controller

  def sign_uptime(conn, %{"data" => %{"nodes" => signs}} = _params) do
    Logger.info("Received sign statuses from ARINC for #{Enum.count(signs)} signs")

    {splunk_time, result} =
      :timer.tc(fn ->
        Enum.each(signs, fn %{"description" => description, "is_online" => is_online} ->
          Logger.info(["sign_description: ", description, " is_online: ", is_online])
        end)
      end)

    Logger.info(["sign_status_to_splunk_ms: ", splunk_time |> div(1000) |> inspect])
    send_resp(conn, 200, "")
  end

  def scu_uptime(conn, _params) do
    send_resp(conn, 200, "")
  end

  def index(conn, params) do
    send_resp(conn, 200, "Hello")
  end
end
