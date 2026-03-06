defmodule Engine.StationStops do
  use GenServer
  require Logger

  @http_client Application.compile_env!(:realtime_signs, :http_client)
  @update_seconds 30 * 60

  @callback get_parent_stop(String.t()) :: String.t() | nil
  def get_parent_stop(stop_id) do
    case :ets.lookup(:station_stops, stop_id) do
      [{^stop_id, parent_id}] -> parent_id
      _ -> nil
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    :ets.new(:station_stops, [:named_table, read_concurrency: true])
    send(self(), :update)

    {:ok, %{last_modified: nil}}
  end

  @impl GenServer
  def handle_info(:update, %{last_modified: last_modified} = state) do
    api_url = Application.get_env(:realtime_signs, :api_v3_url)
    api_key = Application.get_env(:realtime_signs, :api_v3_key)

    case @http_client.get(
           api_url <> "/stops",
           Enum.concat(
             if(last_modified, do: [{"if-modified-since", last_modified}], else: []),
             if(api_key, do: [{"x-api-key", api_key}], else: [])
           ),
           timeout: 10000,
           recv_timeout: 10000,
           params: %{"fields[stop]" => ""}
         ) do
      {:ok, %{status_code: 200, body: body, headers: headers}} ->
        %{"data" => data} = Jason.decode!(body)

        for %{
              "id" => id,
              "relationships" => %{"parent_station" => %{"data" => %{"id" => parent_id}}}
            } <- data,
            uniq: true do
          {id, parent_id}
        end
        |> then(fn records ->
          :ets.insert(:station_stops, records)
        end)

        schedule_update(@update_seconds)
        {:noreply, %{state | last_modified: Map.new(headers)["last-modified"]}}

      {:ok, %{status_code: 304}} ->
        schedule_update(@update_seconds)
        {:noreply, state}

      err ->
        Logger.error("Error getting station stops: #{inspect(err)}")
        if(last_modified, do: @update_seconds, else: 5) |> schedule_update()
        {:noreply, state}
    end
  end

  defp schedule_update(seconds) do
    Process.send_after(self(), :update, seconds * 1000)
  end
end
