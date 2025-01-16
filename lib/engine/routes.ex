defmodule Engine.Routes do
  use GenServer
  require Logger

  @callback route_destination(String.t(), 0 | 1) :: String.t() | nil
  def route_destination(route_id, direction_id) do
    case :ets.lookup(:route_destinations, {route_id, direction_id}) do
      [{{^route_id, ^direction_id}, destination}] -> destination
      _ -> nil
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(:route_destinations, [:named_table, read_concurrency: true])
    send(self(), :update)
    {:ok, %{last_modified: nil}}
  end

  @impl true
  def handle_info(:update, %{last_modified: last_modified} = state) do
    Process.send_after(self(), :update, 30_000)
    api_url = Application.get_env(:realtime_signs, :api_v3_url)
    api_key = Application.get_env(:realtime_signs, :api_v3_key)
    http_client = Application.get_env(:realtime_signs, :http_client)

    case http_client.get(
           api_url <> "/routes",
           Enum.concat(
             if(last_modified, do: [{"if-modified-since", last_modified}], else: []),
             if(api_key, do: [{"x-api-key", api_key}], else: [])
           ),
           timeout: 2000,
           recv_timeout: 2000,
           params: %{"filter[type]" => "3"}
         ) do
      {:ok, %{status_code: 200, body: body, headers: headers}} ->
        %{"data" => data} = Jason.decode!(body)

        for %{"id" => route_id, "attributes" => %{"direction_destinations" => destinations}} <-
              data,
            {destination, direction_id} <- Enum.with_index(destinations) do
          {{route_id, direction_id}, destination}
        end
        |> then(fn records -> :ets.insert(:route_destinations, records) end)

        {:noreply, %{state | last_modified: Map.new(headers)["last-modified"]}}

      {:ok, %{status_code: 304}} ->
        {:noreply, state}

      err ->
        Logger.error("Error getting routes: #{inspect(err)}")
        {:noreply, state}
    end
  end
end
