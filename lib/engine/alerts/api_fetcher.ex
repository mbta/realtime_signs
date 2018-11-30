defmodule Engine.Alerts.ApiFetcher do
  @behaviour Engine.Alerts.Fetcher

  alias Engine.Alerts.StationConfig

  @impl Engine.Alerts.Fetcher
  def get_stop_statuses do
    case get_alerts() do
      {:ok, data} -> {:ok, determine_stop_statuses(data)}
      err -> {:error, err}
    end
  end

  defp get_alerts do
    alerts_url = Application.get_env(:realtime_signs, :api_v3_url) <> "/alerts"

    headers = api_key_headers(Application.get_env(:realtime_signs, :api_v3_key))
    http_client = Application.get_env(:realtime_signs, :http_client)

    with {:ok, req} <-
           http_client.get(
             alerts_url,
             headers,
             timeout: 2000,
             recv_timeout: 2000,
             params: %{
               "filter[route]" => "Green-B,Green-C,Green-D,Green-E,Red,Orange,Blue",
               "filter[datetime]" => "NOW"
             }
           ),
         %{status_code: 200, body: body} <- req,
         {:ok, parsed} <- Poison.Parser.parse(body),
         {:ok, data} <- Map.fetch(parsed, "data") do
      {:ok, data}
    else
      err -> {:error, err}
    end
  end

  defp determine_stop_statuses(alert_data) do
    station_config = StationConfig.load_config()

    Enum.reduce(alert_data, %{}, fn alert, acc ->
      statuses = process_alert(alert, station_config)

      Map.merge(
        acc,
        statuses,
        &higher_priority_status/3
      )
    end)
  end

  defp higher_priority_status(_stop_id, status1, status2)
       when status1 == :shuttles_closed_station or status2 == :shuttles_closed_station do
    :shuttles_closed_station
  end

  defp higher_priority_status(_stop_id, _status1, _status2) do
    :shuttles_transfer_station
  end

  defp process_alert(alert, station_config) do
    if get_in(alert, ["attributes", "effect"]) == "SHUTTLE" do
      alert["attributes"]["informed_entity"]
      |> Enum.flat_map(fn ie ->
        if ie["stop"] do
          [ie["stop"]]
        else
          []
        end
      end)
      |> get_statuses(station_config)
    else
      %{}
    end
  end

  def get_statuses(stop_ids, station_config) do
    stop_ids
    |> Enum.flat_map(fn stop_id ->
      case station_config.stop_to_station[stop_id] do
        station when not is_nil(station) ->
          neighbors = station_config.station_neighbors[station]

          neighbor_stops =
            Enum.flat_map(neighbors, fn n -> station_config.station_to_stops[n] end)

          if Enum.all?(neighbor_stops, fn neighbor -> neighbor in stop_ids end) do
            [{stop_id, :shuttles_closed_station}]
          else
            [{stop_id, :shuttles_transfer_station}]
          end

        _ ->
          []
      end
    end)
    |> Enum.into(%{})
  end

  defp api_key_headers(nil), do: []
  defp api_key_headers(key), do: [{"x-api-key", key}]
end
