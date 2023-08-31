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
          vehicle_locations_table: :ets.tab(),
          stop_locations_table: :ets.tab()
        }

  @vehicle_locations_table :vehicle_locations
  @stop_locations_table :stop_locations

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def for_vehicle(locations_table_id \\ @vehicle_locations_table, vehicle_id) do
    case :ets.lookup(locations_table_id, vehicle_id) do
      [{_, :none}] -> nil
      [{^vehicle_id, location}] -> location
      _ -> nil
    end
  end

  @impl true
  def for_stop(stop_id) do
    case :ets.lookup(@stop_locations_table, stop_id) do
      [{^stop_id, locations}] -> locations
      _ -> []
    end
  end

  @impl true
  def init(_) do
    schedule_update(self())

    state = %{
      last_modified_vehicle_positions: nil,
      vehicle_locations_table: @vehicle_locations_table,
      stop_locations_table: @stop_locations_table
    }

    create_tables(state)
    {:ok, state}
  end

  def create_tables(state) do
    :ets.new(state.vehicle_locations_table, [:named_table, read_concurrency: true])
    :ets.new(state.stop_locations_table, [:named_table, read_concurrency: true])
  end

  @impl true
  def handle_info(:update, state) do
    schedule_update(self())

    full_url = Application.get_env(:realtime_signs, :vehicle_positions_url)

    last_modified_vehicle_locations =
      case download_data(full_url, state.last_modified_vehicle_positions) do
        {:ok, body, new_last_modified} ->
          {locations_by_vehicle, locations_by_stop} = map_locations_data(body)
          write_ets(state.vehicle_locations_table, locations_by_vehicle, :none)
          write_ets(state.stop_locations_table, locations_by_stop, [])
          new_last_modified

        :error ->
          state.last_modified_vehicle_positions
      end

    {:noreply, %{state | last_modified_vehicle_positions: last_modified_vehicle_locations}}
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
        :error

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("Could not fetch file from #{inspect(full_url)}: #{inspect(reason)}")
        :error
    end
  end

  @spec map_locations_data(String.t()) ::
          {%{String.t() => Locations.Location.t()}, %{String.t() => Locations.Location.t()}}
  defp map_locations_data(response) do
    try do
      locations =
        response
        |> Jason.decode!()
        |> Map.get("entity")
        |> Enum.reject(&(&1["vehicle"]["trip"]["schedule_relationship"] == "CANCELED"))
        |> Enum.map(&location_from_update/1)

      {Map.new(locations, fn location -> {location.vehicle_id, location} end),
       Enum.group_by(locations, & &1.stop_id)}
    rescue
      e in Jason.DecodeError ->
        Logger.error(
          "Engine.Locations json_decode_error: #{inspect(Jason.DecodeError.message(e))}"
        )

        {%{}, %{}}
    end
  end

  defp location_from_update(location) do
    %Locations.Location{
      vehicle_id: get_in(location, ["vehicle", "vehicle", "id"]),
      status: vehicle_status_to_atom(location["vehicle"]["current_status"]),
      stop_id: location["vehicle"]["stop_id"],
      timestamp: location["vehicle"]["timestamp"],
      route_id: location["vehicle"]["trip"]["route_id"],
      trip_id: location["vehicle"]["trip"]["trip_id"],
      consist: location["vehicle"]["vehicle"]["consist"],
      multi_carriage_details:
        parse_carriage_details(location["vehicle"]["multi_carriage_details"] || [])
    }
  end

  defp parse_carriage_details(multi_carriage_details) do
    Enum.map(multi_carriage_details, fn carriage_details ->
      %Locations.CarriageDetails{
        label: carriage_details["label"],
        occupancy_status: occupancy_status_to_atom(carriage_details["occupancy_status"]),
        occupancy_percentage: carriage_details["occupancy_percentage"],
        carriage_sequence: carriage_details["carriage_sequence"]
      }
    end)
  end

  defp occupancy_status_to_atom(status) do
    case status do
      "MANY_SEATS_AVAILABLE" -> :many_seats_available
      "FEW_SEATS_AVAILABLE" -> :few_seats_available
      "STANDING_ROOM_ONLY" -> :standing_room_only
      "CRUSHED_STANDING_ROOM_ONLY" -> :crushed_standing_room_only
      "FULL" -> :full
      _ -> :unknown
    end
  end

  defp vehicle_status_to_atom(status) do
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

  defp write_ets(table, values, empty_value) do
    :ets.tab2list(table)
    |> Enum.map(&{elem(&1, 0), empty_value})
    |> Map.new()
    |> Map.merge(values)
    |> Map.to_list()
    |> then(&:ets.insert(table, &1))
  end
end
