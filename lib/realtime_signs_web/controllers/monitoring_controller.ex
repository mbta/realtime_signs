defmodule RealtimeSignsWeb.MonitoringController do
  require Logger
  use RealtimeSignsWeb, :controller

  def uptime(
        conn,
        %{"time" => arinc_time, "device_type" => device_type, "data" => %{"nodes" => nodes}} =
          _params
      ) do
    Logger.info("Received #{device_type} statuses from ARINC for #{Enum.count(nodes)} nodes")

    {:ok, date_time} = DateTime.from_unix(arinc_time, :second)

    {splunk_time, _result} =
      :timer.tc(fn ->
        Enum.each(nodes, fn %{"description" => description, "is_online" => is_online} ->
          Logger.info([
            "device_type: ",
            device_type,
            " description: ",
            description,
            " is_online: ",
            is_online,
            " date_time: ",
            DateTime.to_string(date_time)
          ])
        end)
      end)

    Logger.info(["arinc_device_status_to_splunk_ms: ", splunk_time |> div(1000) |> inspect])
    send_resp(conn, 200, "")
  end

  def index(conn, _params) do
    send_resp(conn, 200, "Hello")
  end
end
