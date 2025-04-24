defmodule Engine.BusPredictions do
  use GenServer
  require Logger

  @callback predictions_for_stop(String.t()) :: [Predictions.BusPrediction.t()]
  def predictions_for_stop(id) do
    case :ets.lookup(:bus_predictions, id) do
      [{^id, predictions}] -> predictions
      _ -> []
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    :ets.new(:bus_predictions, [:named_table, read_concurrency: true])
    schedule_update(self())

    {:ok,
     %{
       last_modified: nil,
       all_bus_stop_ids: Signs.Utilities.SignsConfig.all_bus_stop_ids()
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

    case http_client.get(
           api_url <> "/predictions",
           Enum.concat(
             if(last_modified, do: [{"if-modified-since", last_modified}], else: []),
             if(api_key, do: [{"x-api-key", api_key}], else: [])
           ),
           timeout: 2000,
           recv_timeout: 2000,
           params: %{
             "include" => "trip,vehicle,stop",
             "fields[prediction]" => "departure_time,direction_id",
             "fields[trip]" => "headsign",
             "fields[vehicle]" => "updated_at",
             "filter[stop]" => Enum.join(all_bus_stop_ids, ",")
           }
         ) do
      {:ok, %{status_code: 200, body: body, headers: headers}} ->
        %{"data" => data} = payload = Jason.decode!(body)
        included = Map.get(payload, "included", [])

        vehicles_lookup =
          for %{
                "type" => "vehicle",
                "id" => id,
                "attributes" => %{"updated_at" => updated_at}
              } <- included,
              into: %{} do
            {id, %{id: id, updated_at: updated_at}}
          end

        trips_lookup =
          for %{
                "type" => "trip",
                "id" => id,
                "attributes" => %{"headsign" => headsign},
                "relationships" => %{
                  "route" => %{"data" => %{"id" => route_id}}
                }
              } <- included,
              into: %{} do
            {id, %{id: id, headsign: headsign, route_id: route_id}}
          end

        new_predictions =
          for %{
                "attributes" => %{
                  "direction_id" => direction_id,
                  "departure_time" => departure_time
                },
                "relationships" => %{
                  "route" => %{"data" => %{"id" => route_id}},
                  "stop" => %{"data" => %{"id" => stop_id}},
                  "trip" => %{"data" => %{"id" => trip_id}},
                  "vehicle" => %{"data" => vehicle_data}
                }
              } <- data,
              # Multi-route trips will have duplicate predictions for each route.
              # To filter them out, we only keep the one whose route_id matches the trip's.
              route_id == trips_lookup[trip_id].route_id do
            vehicle_id =
              case vehicle_data do
                %{"id" => vehicle_id} -> vehicle_id
                _ -> nil
              end

            %Predictions.BusPrediction{
              direction_id: direction_id,
              departure_time:
                if(departure_time, do: Timex.parse!(departure_time, "{ISO:Extended}")),
              route_id: route_id,
              stop_id: stop_id,
              headsign: trips_lookup[trip_id].headsign,
              vehicle_id: vehicle_id,
              trip_id: trip_id,
              updated_at: if(vehicle_id, do: vehicles_lookup[vehicle_id].updated_at)
            }
          end
          |> Enum.group_by(& &1.stop_id)

        Enum.map(all_bus_stop_ids, &{&1, []})
        |> Map.new()
        |> Map.merge(new_predictions)
        |> Map.to_list()
        |> then(fn records -> :ets.insert(:bus_predictions, records) end)

        {:noreply, %{state | last_modified: Map.new(headers)["last-modified"]}}

      {:ok, %{status_code: 304}} ->
        {:noreply, state}

      err ->
        Logger.error("Error getting bus predictions: #{inspect(err)}")
        {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    Logger.warning("Engine.BusPredictions unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end
end
