defmodule Monitoring.Uptime do
  require Logger

  @spec monitor_device_uptime(list(map()), integer()) :: :ok
  def monitor_device_uptime(nodes, timestamp) do
    {:ok, date_time} = DateTime.from_unix(timestamp, :second)

    {splunk_time, :ok} =
      :timer.tc(fn ->
        Enum.each(nodes, fn node ->
          log_device_status(node, date_time)
        end)
      end)

    Logger.info("arinc_status_to_splunk_ms: #{div(splunk_time, 1000)}")
  end

  defp log_device_status(
         %{"description" => description, "is_online" => is_online} = node,
         date_time
       ) do
    case get_device_type(node) do
      :scu ->
        [line, station, scu_id | _] = String.split(description, ":")

        Logger.info([
          "device_uptime: ",
          "date_time=",
          DateTime.to_string(date_time),
          " device_type=scu",
          " line=",
          line,
          " station=",
          String.replace(station, " ", "_"),
          " scu_id=",
          scu_id,
          " is_online=",
          is_online
        ])

      :sign ->
        [line, station, sign_id, sign_zone] = String.split(description, ":")

        Logger.info([
          "device_uptime: ",
          "date_time=",
          DateTime.to_string(date_time),
          " device_type=sign",
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
        Logger.warn(
          "Received uptime info of a node with an unknown or unspecified type #{inspect(node)}"
        )
    end
  end

  defp get_device_type(%{"node_type" => node_type} = _node) do
    case node_type do
      "SGN" -> :sign
      "PSS" -> :scu
      _ -> :unknown
    end
  end

  defp get_device_type(_), do: :unspecified
end
