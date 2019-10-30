defmodule Engine.Predictions do
  @moduledoc """
  Maintains an up-to-date internal state of the realtime predictions of vehicles
  in the system. Fetches from the GTFS-rt enhanced JSON file about once per
  second.

  Offers a `for_stop/1` public interface to get a list of Predictions.Prediction's
  for a given GTFS stop.
  """

  use GenServer
  require Logger

  @type state :: %{
          last_modified_trip_updates: String.t() | nil,
          last_modified_vehicle_positions: String.t() | nil,
          trip_updates_table: :ets.tab()
        }

  @trip_updates_table :trip_updates

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "The upcoming predicted times a vehicle will be at this stop"
  @spec for_stop(String.t(), 0 | 1) :: [Predictions.Prediction.t()]
  def for_stop(predictions_table_id \\ @trip_updates_table, gtfs_stop_id, direction_id) do
    case :ets.lookup(predictions_table_id, {gtfs_stop_id, direction_id}) do
      [{_, :none}] -> []
      [{{^gtfs_stop_id, ^direction_id}, predictions}] -> predictions
      _ -> []
    end
  end

  def init(_) do
    schedule_update(self())

    @trip_updates_table =
      :ets.new(@trip_updates_table, [:set, :protected, :named_table, read_concurrency: true])

    {:ok,
     %{
       last_modified_trip_updates: nil,
       last_modified_vehicle_positions: nil,
       trip_updates_table: @trip_updates_table
     }}
  end

  def handle_info(:update, state) do
    schedule_update(self())
    current_time = Timex.now()

    {last_modified_trip_updates, vehicles_running_revenue_trips} =
      download_and_insert_data(
        state[:last_modified_trip_updates],
        current_time,
        &update_predictions/3,
        :trip_update_url,
        state[:trip_updates_table]
      )

    {last_modified_vehicle_positions, stops_with_trains} =
      download_and_process_vehicle_positions(
        state[:last_modified_vehicle_positions],
        :vehicle_positions_url
      )

    if vehicles_running_revenue_trips && stops_with_trains do
      Engine.Departures.update_train_state(
        stops_with_trains,
        vehicles_running_revenue_trips,
        current_time
      )

      {:noreply,
       %{
         state
         | last_modified_trip_updates: last_modified_trip_updates,
           last_modified_vehicle_positions: last_modified_vehicle_positions
       }}
    else
      {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    Logger.warn("#{__MODULE__} unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  @spec update_predictions(any(), DateTime.t(), :ets.tab()) :: MapSet.t(String.t())
  defp update_predictions(body, current_time, predictions_table) do
    {new_predictions, vehicles_running_revenue_trips} =
      body
      |> Predictions.Predictions.parse_json_response()
      |> Predictions.Predictions.get_all(current_time)

    existing_predictions =
      :ets.tab2list(predictions_table) |> Enum.map(&{elem(&1, 0), :none}) |> Map.new()

    all_predictions = Map.merge(existing_predictions, new_predictions)
    :ets.insert(predictions_table, Enum.into(all_predictions, []))

    vehicles_running_revenue_trips
  end

  @spec download_and_insert_data(
          String.t() | nil,
          DateTime.t(),
          (any(), DateTime.t(), :ets.tab() -> any()),
          atom,
          :ets.tab()
        ) :: {String.t() | nil, any()}
  defp download_and_insert_data(last_modified, current_time, parse_and_update_fn, url, ets_table) do
    full_url = Application.get_env(:realtime_signs, url)

    case download_data(full_url, last_modified) do
      {:ok, body, new_last_modified} ->
        {new_last_modified, parse_and_update_fn.(body, current_time, ets_table)}

      :error ->
        {last_modified, nil}
    end
  end

  @spec download_and_process_vehicle_positions(String.t() | nil, atom()) ::
          {String.t() | nil, %{String.t() => String.t()} | nil}
  defp download_and_process_vehicle_positions(last_modified, url) do
    full_url = Application.get_env(:realtime_signs, url)

    case download_data(full_url, last_modified) do
      {:ok, body, new_last_modified} ->
        {new_last_modified, vehicle_positions_response_to_stops_with_trains(body)}

      :error ->
        {last_modified, nil}
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
        :error

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("Could not fetch file from #{inspect(full_url)}: #{inspect(reason)}")
        :error
    end
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end

  @spec vehicle_positions_response_to_stops_with_trains(String.t()) :: %{String.t() => String.t()}
  defp vehicle_positions_response_to_stops_with_trains(response) do
    try do
      response
      |> Poison.Parser.parse!()
      |> Map.get("entity")
      |> Enum.filter(fn vehicle_position ->
        get_in(vehicle_position, ["vehicle", "current_status"]) == "STOPPED_AT"
      end)
      |> Map.new(fn vehicle_position ->
        {get_in(vehicle_position, ["vehicle", "stop_id"]),
         get_in(vehicle_position, ["vehicle", "vehicle", "id"])}
      end)
    rescue
      Poison.SyntaxError -> %{}
    end
  end
end
