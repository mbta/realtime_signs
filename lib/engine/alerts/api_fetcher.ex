defmodule Engine.Alerts.ApiFetcher do
  @behaviour Engine.Alerts.Fetcher

  alias Engine.Alerts.StationConfig

  @impl Engine.Alerts.Fetcher

  @spec get_statuses() ::
          {:ok,
           %{
             :stop_statuses => %{
               Engine.Alerts.Fetcher.stop_id() => Engine.Alerts.Fetcher.stop_status()
             },
             :route_statuses => %{
               Engine.Alerts.Fetcher.route_id() => Engine.Alerts.Fetcher.stop_status()
             }
           }}
          | {:error, any()}
  def get_statuses do
    case get_alerts() do
      {:ok, data} ->
        {stop_statuses, route_statuses} = determine_stop_statuses(data)
        route_statuses = Map.merge(route_statuses, determine_route_statuses(data))

        {:ok,
         %{
           :stop_statuses => stop_statuses,
           :route_statuses => route_statuses
         }}

      err ->
        {:error, err}
    end
  end

  @spec get_alerts() :: {:ok, [%{}]} | {:error, atom()}
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
               "filter[route]" =>
                 "Green-B,Green-C,Green-D,Green-E,Red,Orange,Blue,Mattapan,741,742,743,746",
               "filter[datetime]" => "NOW"
             }
           ),
         %{status_code: 200, body: body} <- req,
         {:ok, parsed} <- Jason.decode(body),
         {:ok, data} <- Map.fetch(parsed, "data") do
      {:ok, data}
    else
      err -> {:error, err}
    end
  end

  @spec determine_stop_statuses([%{}]) ::
          {%{
             Engine.Alerts.Fetcher.stop_id() => Engine.Alerts.Fetcher.stop_status()
           }, %{Engine.Alerts.Fetcher.route_id() => :alert_along_route}}
  defp determine_stop_statuses(alert_data) do
    station_config = StationConfig.load_config()

    {stop_statuses, routes} =
      Enum.reduce(alert_data, {%{}, %{}}, fn alert, {acc_stop_statuses, routes} = _acc ->
        {stop_statuses, alert_routes} = process_alert_for_stations(alert, station_config)

        routes = Map.merge(routes, alert_routes)

        stop_statuses =
          Map.merge(acc_stop_statuses, stop_statuses, fn _stop_id, s1, s2 ->
            Engine.Alerts.Fetcher.higher_priority_status(s1, s2)
          end)

        {stop_statuses, routes}
      end)

    {stop_statuses, routes}
  end

  @spec determine_route_statuses([%{}]) :: %{Engine.Alerts.Fetcher.stop_id() => any()}
  defp determine_route_statuses(alert_data) do
    Enum.reduce(alert_data, %{}, fn alert, acc ->
      statuses = process_alert_for_routes(alert)

      Map.merge(acc, statuses, fn _stop_id, s1, s2 ->
        Engine.Alerts.Fetcher.higher_priority_status(s1, s2)
      end)
    end)
  end

  @spec process_alert_for_stations(%{}, %StationConfig{}) ::
          {%{
             Engine.Alerts.Fetcher.stop_id() => Engine.Alerts.Fetcher.stop_status()
           }, %{Engine.Alerts.Fetcher.route_id() => :alert_along_route}}
  defp process_alert_for_stations(alert, station_config) do
    stops = stops_for_alert(alert)
    alert_effect = get_in(alert, ["attributes", "effect"])

    routes =
      if alert_effect in ["SHUTTLE", "SUSPENSION"] do
        alert
        |> routes_for_alert()
        |> Enum.reduce(%{}, fn route, acc ->
          Map.merge(acc, %{route => :alert_along_route})
        end)
      else
        %{}
      end

    stop_alerts =
      case alert_effect do
        "SHUTTLE" ->
          stops
          |> get_alert_statuses(station_config, :shuttle)

        "SUSPENSION" ->
          stops
          |> get_alert_statuses(station_config, :suspension)

        "STATION_CLOSURE" ->
          stops
          |> Enum.map(&{&1, :station_closure})
          |> Enum.into(%{})

        "STOP_CLOSURE" ->
          stops
          |> Enum.map(&{&1, :station_closure})
          |> Enum.into(%{})

        _ ->
          %{}
      end

    {stop_alerts, routes}
  end

  @spec stops_for_alert(%{}) :: [Engine.Alerts.Fetcher.stop_id()]
  defp stops_for_alert(alert) do
    alert["attributes"]["informed_entity"]
    |> Enum.flat_map(fn ie ->
      if ie["stop"] do
        [ie["stop"]]
      else
        []
      end
    end)
  end

  @spec routes_for_alert(%{}) :: [Engine.Alerts.Fetcher.route_id()]
  defp routes_for_alert(alert) do
    alert["attributes"]["informed_entity"]
    |> Enum.flat_map(fn ie ->
      if ie["route"] do
        [ie["route"]]
      else
        []
      end
    end)
  end

  @spec process_alert_for_routes(%{}) :: %{
          Engine.Alerts.Fetcher.route_id() => Engine.Alerts.Fetcher.stop_status()
        }
  defp process_alert_for_routes(alert) do
    alert["attributes"]["informed_entity"]
    |> Enum.flat_map(fn ie ->
      if !("stop" in Map.keys(ie)) do
        case get_in(alert, ["attributes", "effect"]) do
          "SUSPENSION" ->
            [{ie["route"], :suspension_closed_station}]

          "SHUTTLE" ->
            [{ie["route"], :shuttles_closed_station}]

          "STATION_CLOSURE" ->
            [{ie["route"], :station_closure}]

          "STOP_CLOSURE" ->
            [{ie["route"], :station_closure}]

          _ ->
            []
        end
      else
        []
      end
    end)
    |> Enum.into(%{})
  end

  @spec get_alert_statuses([String.t()], %Engine.Alerts.StationConfig{}, :shuttle | :suspension) ::
          %{}
  def get_alert_statuses(stop_ids, station_config, alert_type) do
    stop_ids
    |> Enum.flat_map(fn stop_id ->
      case station_config.stop_to_station[stop_id] do
        station when not is_nil(station) ->
          neighbors = station_config.station_neighbors[station]

          neighbor_stops =
            Enum.flat_map(neighbors, fn n -> station_config.station_to_stops[n] end)

          if Enum.all?(neighbor_stops, fn neighbor -> neighbor in stop_ids end) do
            [
              {stop_id,
               if(
                 alert_type == :shuttle,
                 do: :shuttles_closed_station,
                 else: :suspension_closed_station
               )}
            ]
          else
            [
              {stop_id,
               if(
                 alert_type == :shuttle,
                 do: :shuttles_transfer_station,
                 else: :suspension_transfer_station
               )}
            ]
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
