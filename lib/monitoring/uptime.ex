defmodule Monitoring.Uptime do
  require Logger

  @spec monitor_node_uptime(list(map()), integer()) :: :ok
  def monitor_node_uptime(nodes, timestamp) do
    {:ok, date_time} = DateTime.from_unix(timestamp, :second)

    Enum.each(nodes, fn node ->
      prefix = get_prefix(node)

      log_fields =
        case prefix do
          "software_uptime" ->
            get_live_pa_app_fields(node)

          "headend_server_stats" ->
            get_headend_server_fields(node)

          "live_pa_connectivity" ->
            get_live_pa_connectivity_fields(node)

          "device_uptime" ->
            get_device_status_fields(node)

          "unknown" ->
            Logger.warn("unknown_node: ", inspect(node))
            []
        end

      log(prefix, date_time, log_fields)
    end)
  end

  defp get_prefix(%{"sw_component" => _}), do: "software_uptime"
  defp get_prefix(%{"TotalMemory" => _}), do: "headend_server_stats"
  defp get_prefix(%{"Location ID" => _}), do: "live_pa_connectivity"
  defp get_prefix(%{"node_type" => _}), do: "device_uptime"
  defp get_prefix(_), do: "unknown"

  defp get_live_pa_connectivity_fields(%{
         "Location ID" => station_code,
         "IP Address" => ip_address,
         "Status" => status
       }) do
    [
      station_code: station_code,
      ip_address: ip_address,
      status: String.replace(status, " ", "_")
    ]
  end

  defp get_headend_server_fields(%{
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

    [
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
    ]
  end

  defp get_live_pa_app_fields(%{
         "sw_component" => sw_component,
         "is_online" => is_online,
         "status" => status
       }) do
    [
      application: String.replace(sw_component, " ", "_"),
      is_online: is_online,
      status: status
    ]
  end

  defp get_device_status_fields(%{"description" => description, "is_online" => is_online} = node) do
    device_type = get_device_type(node)

    [line, station, device_id, maybe_sign_zone] = String.split(description, ":")

    log_fields = [
      node_type: device_type,
      line: line,
      station: String.replace(station, " ", "_"),
      device_id: device_id,
      is_online: is_online
    ]

    if device_type == "sign",
      do: log_fields ++ [sign_zone: maybe_sign_zone],
      else: log_fields
  end

  defp get_device_type(%{"node_type" => node_type}) do
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

  def log(_, _, []) do
    nil
  end

  def log(prefix, date_time, fields) do
    base = [
      "#{prefix}: ",
      "date_time=",
      DateTime.to_string(date_time)
    ]

    Enum.reduce(fields, base, fn {k, v}, acc ->
      acc ++ [" #{Atom.to_string(k)}=", v]
    end)
    |> Logger.info()
  end
end
