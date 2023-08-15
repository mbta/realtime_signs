defmodule Engine.Locations do
  @moduledoc """
  Maintains an up-to-date internal state of the realtime locations of vehicles in the system. Fetches
  from the GTFS-rt enhanced JSON file about once per second.
  """
  @behaviour Engine.LocationsAPI

  use GenServer
  require Logger

  @type state :: %{
          last_modified_vehicle_positions: String.t() | nil,
          vehicle_locations_table: :ets.tab()
        }

  @vehicle_locations_table :vehicle_locations

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def for_vehicle(vehicle_id) do
    case :ets.lookup(@vehicle_locations_table, vehicle_id) do
      [{_, :none}] -> nil
      [{^vehicle_id, location}] -> location
      _ -> nil
    end
  end

  @impl true
  def init(_) do
    schedule_update(self())

    @vehicle_locations_table =
      :ets.new(
        @vehicle_locations_table,
        [:set, :protected, :named_table, read_concurrency: true]
      )

    {:ok,
     %{last_modified_vehicle_positions: nil, vehicle_locations_table: @vehicle_locations_table}}
  end

  @impl true
  def handle_info(:update, state) do
    schedule_update(self())

    last_modified_vehicle_locations =
      download_and_process_vehicle_locations(
        state[:last_modified_vehicle_positions],
        :vehicle_positions_url,
        state[:vehicle_locations_table]
      )

    {:noreply, %{state | last_modified_vehicle_positions: last_modified_vehicle_locations}}
  end

  @spec download_and_process_vehicle_locations(String.t() | nil, atom(), :ets.tab()) ::
          String.t()
  defp download_and_process_vehicle_locations(last_modified, url, ets_table) do
    full_url = Application.get_env(:realtime_signs, url)

    case download_data(full_url, last_modified) do
      {:ok, body, new_last_modified} ->
        existing_vehicles =
          :ets.tab2list(ets_table) |> Enum.map(&{elem(&1, 0), :none}) |> Map.new()

        all_vehicles = Map.merge(existing_vehicles, map_locations_data(body))
        :ets.insert(ets_table, Enum.into(all_vehicles, []))

        new_last_modified

      :error ->
        last_modified
    end
  end

  @spec download_data(String.t(), String.t() | nil) ::
          {:ok, String.t(), String.t() | nil} | :error
  defp download_data(full_url, last_modified) do
    http_client = Application.get_env(:realtime_signs, :http_client)

    case http_client.get(
           full_url,
           if last_modified do
             [{"If-Modified-Since", last_modified}]
           else
             []
           end,
           timeout: 2000,
           recv_timeout: 2000
         ) do
      {:ok, %HTTPoison.Response{body: body, status_code: status, headers: headers}}
      when status >= 200 and status < 300 ->
        case Enum.find(headers, fn {header, _value} -> header == "Last-Modified" end) do
          {"Last-Modified", last_modified} -> {:ok, body, last_modified}
          _ -> {:ok, body, nil}
        end

      {:ok, %HTTPoison.Response{}} ->
        IO.puts("HERE")
        :error

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("Could not fetch file from #{inspect(full_url)}: #{inspect(reason)}")
        :error
    end
  end

  @spec map_locations_data(String.t()) :: %{String.t() => String.t()}
  defp map_locations_data(response) do
    try do
      response
      |> Jason.decode!()
      |> Map.get("entity")
      |> Enum.reject(&(&1["vehicle"]["trip"]["schedule_relationship"] == "CANCELED"))
      |> Enum.map(&location_from_update/1)
      |> Map.new(fn location ->
        {location.vehicle_id, location}
      end)
    rescue
      Jason.DecodeError -> %{}
    end
  end

  defp location_from_update(location) do
    %Locations.Location{
      vehicle_id: get_in(location, ["vehicle", "vehicle", "id"]),
      status: status_to_atom(location["vehicle"]["current_status"]),
      stop_id: location["vehicle"]["stop_id"],
      timestamp: location["vehicle"]["timestamp"],
      route_id: location["vehicle"]["trip"]["route_id"],
      trip_id: location["vehicle"]["trip"]["trip_id"],
      consist: location["vehicle"]["vehicle"]["consist"]
    }
  end

  defp status_to_atom(status) do
    case status do
      "INCOMING_AT" -> :incoming_at
      "STOPPED_AT" -> :stopped_at
      "IN_TRANSIT_TO" -> :in_transit_to
      _ -> :unknown
    end
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end
end
