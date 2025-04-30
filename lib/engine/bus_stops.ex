defmodule Engine.BusStops do
  alias Signs.Utilities.SignsConfig
  use GenServer
  require Logger

  @bus_vehicle_type 3

  @callback get_child_stop(String.t(), String.t(), String.t()) :: String.t()
  def get_child_stop(parent_stop_id, route_id, direction_id) do
    case :ets.lookup(:child_stops, {parent_stop_id, route_id, direction_id}) do
      [{{^parent_stop_id, ^route_id, ^direction_id}, child_stop}] -> child_stop
      _ -> nil
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    :ets.new(:child_stops, [:named_table, read_concurrency: true])
    send(self(), :update)

    {:ok,
     %{
       last_modified: nil,
       all_bus_stop_ids: SignsConfig.all_bus_stop_ids()
     }}
  end

  def handle_info(
        :update,
        %{last_modified: last_modified, all_bus_stop_ids: all_bus_stop_ids} = state
      ) do
    schedule_update(self())
    api_url = Application.get_env(:realtime_signs, :api_v3_url)
    api_key = Application.get_env(:realtime_signs, :api_v3_key)
    http_client = Application.get_env(:realtime_signs, :http_client)
    parent_route_directions = SignsConfig.all_bus_stop_route_direction_ids() |> MapSet.new()
    bus_routes = Enum.map(parent_route_directions, &elem(&1, 1)) |> Enum.uniq()

    case http_client.get(
           api_url <> "/schedules",
           Enum.concat(
             if(last_modified, do: [{"if-modified-since", last_modified}], else: []),
             if(api_key, do: [{"x-api-key", api_key}], else: [])
           ),
           timeout: 10000,
           recv_timeout: 10000,
           params: %{
             "filter[stop]" => Enum.join(all_bus_stop_ids, ","),
             "filter[route]" => Enum.join(bus_routes, ","),
             "include" => "stop"
           }
         ) do
      {:ok, %{status_code: 200, body: body, headers: headers}} ->
        %{"data" => data} = payload = Jason.decode!(body)
        included = Map.get(payload, "included", [])

        child_to_parent =
          for %{
                "type" => "stop",
                "id" => child_stop_id,
                "attributes" => %{"vehicle_type" => @bus_vehicle_type},
                "relationships" => %{
                  "parent_station" => %{"data" => %{"id" => parent_stop_id}}
                }
              } <-
                included do
            {child_stop_id, parent_stop_id}
          end
          |> Map.new()

        for %{
              "attributes" => %{"direction_id" => direction_id},
              "relationships" => %{
                "stop" => %{
                  "data" => %{"id" => stop_id}
                },
                "route" => %{"data" => %{"id" => route_id}}
              }
            } <- data,
            parent_stop_id = Map.get(child_to_parent, stop_id),
            {parent_stop_id, route_id, direction_id} in parent_route_directions do
          {{parent_stop_id, route_id, direction_id}, stop_id}
        end
        |> then(fn records ->
          :ets.insert(:child_stops, records)
        end)

        {:noreply, %{state | last_modified: Map.new(headers)["last-modified"]}}

      {:ok, %{status_code: 304}} ->
        {:noreply, state}

      err ->
        Logger.error("Error getting bus schedules: #{inspect(err)}")
        []
    end
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 60_000)
  end
end
