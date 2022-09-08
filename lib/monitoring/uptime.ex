defmodule Monitoring.Uptime do
  require Logger

  @spec monitor_node_uptime(list(map()), integer()) :: :ok
  def monitor_node_uptime(nodes, timestamp) do
    {:ok, date_time} = DateTime.from_unix(timestamp, :second)

    {splunk_time, :ok} =
      :timer.tc(fn ->
        Enum.each(nodes, fn node ->
          log_node_status(node, date_time)
        end)
      end)

    Logger.info("arinc_status_to_splunk_ms: #{div(splunk_time, 1000)}")
  end

  defp log_node_status(
         %{"sw_component" => _, "is_online" => is_online, "status" => status} = node,
         date_time
       ) do
    case get_software_component_type(node) do
      :live_pa ->
        Logger.info([
          "software_uptime: ",
          "date_time=",
          DateTime.to_string(date_time),
          " application=live_pa",
          " is_online=",
          is_online,
          " status=",
          status
        ])

      _ ->
        Logger.warn(
          "Received uptime info of a node with an unknown or unspecified type #{inspect(node)}"
        )
    end
  end

  defp log_node_status(
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
          String.replace(station, " ", "_"),
          " sign_id=",
          sign_id,
          " sign_zone=",
          sign_zone,
          " is_online=",
          is_online
        ])

      :dsp ->
        [line, station, dsp_id | _] = String.split(description, ":")

        Logger.info([
          "device_uptime: ",
          "date_time=",
          DateTime.to_string(date_time),
          " device_type=dsp",
          " line=",
          line,
          " station=",
          String.replace(station, " ", "_"),
          " dsp_id=",
          dsp_id,
          " is_online=",
          is_online
        ])

      :amplifier ->
        [line, station, amp_id | _] = String.split(description, ":")

        Logger.info([
          "device_uptime: ",
          "date_time=",
          DateTime.to_string(date_time),
          " device_type=amp",
          " line=",
          line,
          " station=",
          String.replace(station, " ", "_"),
          " amp_id=",
          amp_id,
          " is_online=",
          is_online
        ])

      :comrex ->
        [line, station, comrex_id | _] = String.split(description, ":")

        Logger.info([
          "device_uptime: ",
          "date_time=",
          DateTime.to_string(date_time),
          " device_type=comrex",
          " line=",
          line,
          " station=",
          String.replace(station, " ", "_"),
          " comrex_id=",
          comrex_id,
          " is_online=",
          is_online
        ])

      _ ->
        Logger.warn(
          "Received uptime info of a node with an unknown or unspecified type #{inspect(node)}"
        )
    end
  end

  defp get_software_component_type(%{"sw_component" => sw_component}) do
    case sw_component do
      "Live PA" ->
        :live_pa

      _ ->
        :unknown
    end
  end

  defp get_device_type(%{"node_type" => node_type} = _node) do
    case node_type do
      "SGN" ->
        :sign

      "PSS" ->
        :scu

      "P8810" ->
        :dsp

      "C4200" ->
        :amplifier

      "DGTY" ->
        :comrex

      _ ->
        :unknown
    end
  end

  defp get_device_type(_), do: :unspecified
end
