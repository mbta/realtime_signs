defmodule Monitoring.Uptime do
  require Logger

  @spec monitor_device_uptime(list(map()), integer()) :: :ok
  def monitor_device_uptime(nodes, timestamp) do
    {:ok, date_time} = DateTime.from_unix(timestamp, :second)
    device_type = get_device_type(nodes)

    {splunk_time, :ok} =
      :timer.tc(fn ->
        Enum.each(nodes, fn %{"description" => description, "is_online" => is_online} ->
          log_device_status(device_type, description, is_online, date_time)
        end)
      end)

    Logger.info(["arinc_status_to_splunk_ms: ", splunk_time |> div(1000) |> inspect])
  end

  defp log_device_status(device_type, description, is_online, date_time) do
    case String.split(description, ":") do
      [line, station, scu_id, "SCU"] ->
        Logger.info([
          "date_time=",
          DateTime.to_string(date_time),
          " device_type=",
          device_type,
          " line=",
          line,
          " station=",
          station,
          " scu_id=",
          scu_id,
          " is_online=",
          is_online
        ])

      [line, station, sign_id, sign_zone] ->
        Logger.info([
          "date_time=",
          DateTime.to_string(date_time),
          " device_type=",
          device_type,
          " line=",
          line,
          " station=",
          station,
          " sign_id=",
          sign_id,
          " sign_zone=",
          sign_zone,
          " is_online=",
          is_online
        ])

      _ ->
        nil
    end
  end

  defp get_device_type(nodes) do
    [%{"node_type" => node_type} | _] = nodes

    case node_type do
      "SGN" -> "sign"
      "PSS" -> "scu"
    end
  end
end
