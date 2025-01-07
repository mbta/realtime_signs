defmodule Monitoring.Uptime do
  require Logger

  @spec monitor_nodes(list(map()), integer()) :: :ok
  def monitor_nodes(nodes, timestamp) do
    {:ok, date_time} = DateTime.from_unix(timestamp, :second)

    Enum.each(nodes, fn node ->
      case get_log_fields(node) do
        {:ok, log_fields} ->
          log([date_time: date_time] ++ log_fields)

        :error ->
          Logger.warn("unknown_node: #{inspect(node)}")
      end
    end)
  end

  defp get_log_fields(%{
         "Location ID" => station_code,
         "IP Address" => ip_address,
         "Status" => status
       }) do
    {:ok,
     [
       tag: "live_pa_connectivity",
       station_code: station_code,
       ip_address: ip_address,
       status: String.replace(status, " ", "_")
     ]}
  end

  defp get_log_fields(%{
         "IPAddress" => ip_address,
         "Uptime" => uptime,
         "TotalMemory" => total_memory,
         "Total_C_Space" => total_c_space,
         "Total_D_Space" => total_d_space,
         "AvailableMemory" => available_memory,
         "Available_C_Space" => available_c_space,
         "Available_D_Space" => available_d_space
       }) do
    [days, hours, minutes] =
      String.split(uptime, ",")
      |> Enum.map(&(String.trim_leading(&1) |> String.split() |> List.first()))

    {:ok,
     [
       tag: "headend_server_stats",
       ip_address: ip_address,
       uptime_days: days,
       uptime_hours: hours,
       uptime_minutes: minutes,
       total_memory: total_memory,
       total_c_space: total_c_space,
       total_d_space: total_d_space,
       available_memory: available_memory,
       available_c_space: available_c_space,
       available_d_space: available_d_space
     ]}
  end

  defp get_log_fields(%{
         "sw_component" => sw_component,
         "is_online" => is_online,
         "status" => status
       }) do
    {:ok,
     [
       tag: "software_uptime",
       node_type: String.replace(sw_component, " ", "_"),
       is_online: is_online,
       status: status
     ]}
  end

  defp get_log_fields(%{"description" => description, "is_online" => is_online} = node) do
    node_type = get_node_type(node)

    [line, station, device_id | rest] = String.split(description, ":")
    maybe_sign_zone = List.first(rest)

    log_fields = [
      tag: "device_uptime",
      node_type: node_type,
      line: line,
      station: String.replace(station, " ", "_"),
      device_id: device_id,
      is_online: is_online
    ]

    {:ok,
     if(node_type == "sign",
       do: log_fields ++ [sign_zone: maybe_sign_zone],
       else: log_fields
     )}
  end

  defp get_log_fields(_), do: :error

  defp get_node_type(%{"node_type" => node_type}) do
    case node_type do
      "SGN" ->
        "sign"

      "PSS" ->
        "scu"

      "P8810" ->
        "dsp"

      "BLU-80" ->
        "dsp"

      "C4200" ->
        "amplifier"

      "DGTY" ->
        "comrex"

      _ ->
        "unknown"
    end
  end

  defp log(fields) do
    formatted_fields =
      Enum.map(fields, fn {k, v} ->
        "#{k}=#{v}"
      end)
      |> Enum.join(" ")

    Logger.info(formatted_fields)
  end
end
