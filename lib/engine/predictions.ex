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
          last_modified_trip_updates: DateTime.t(),
          last_modified_vehicle_positions: DateTime.t(),
          trip_updates_table: :ets.tab()
        }

  @trip_updates_table :trip_updates

  @last_modified_time_format "{WDshort}, {D} {Mshort} {YYYY} {h24}:{m}:{s} {Zabbr}"

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
       last_modified_trip_updates: Timex.now(),
       last_modified_vehicle_positions: Timex.now(),
       trip_updates_table: @trip_updates_table
     }}
  end

  def handle_info(:update, state) do
    schedule_update(self())
    current_time = Timex.now()

    last_modified_trip_updates =
      download_and_insert_data(
        state[:last_modified_trip_updates],
        current_time,
        &update_predictions/3,
        :trip_update_url,
        state[:trip_updates_table]
      )

    {_last_modified_vehicle_positions, _stops_with_trains} =
      download_and_process_vehicle_positions(
        state[:last_modified_vehicle_positions],
        current_time,
        :vehicle_positions_url
      )

    {:noreply, Map.put(state, :last_modified_trip_updates, last_modified_trip_updates)}
  end

  def handle_info(msg, state) do
    Logger.warn("#{__MODULE__} unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp format_last_modified(time) do
    {:ok, last_modified} = Timex.format(time, @last_modified_time_format)

    last_modified
  end

  @spec update_predictions(any(), DateTime.t(), :ets.tab()) :: true
  defp update_predictions(body, current_time, predictions_table) do
    new_predictions =
      body
      |> Predictions.Predictions.parse_json_response()
      |> Predictions.Predictions.get_all(current_time)

    existing_predictions =
      :ets.tab2list(predictions_table) |> Enum.map(&{elem(&1, 0), :none}) |> Map.new()

    all_predictions = Map.merge(existing_predictions, new_predictions)
    :ets.insert(predictions_table, Enum.into(all_predictions, []))
  end

  @spec download_and_insert_data(
          DateTime.t(),
          DateTime.t(),
          (any(), DateTime.t(), :ets.tab() -> true),
          atom,
          :ets.tab()
        ) :: DateTime.t()
  defp download_and_insert_data(last_modified, current_time, parse_and_update_fn, url, ets_table) do
    full_url = Application.get_env(:realtime_signs, url)

    case download_data(full_url, last_modified) do
      {:ok, body, new_last_modified} ->
        parse_and_update_fn.(body, new_last_modified, ets_table)
        new_last_modified || current_time

      :error ->
        last_modified
    end
  end

  @spec download_and_process_vehicle_positions(DateTime.t(), DateTime.t(), atom()) ::
          {DateTime.t(), %{String.t() => String.t()}}
  defp download_and_process_vehicle_positions(last_modified, current_time, url) do
    full_url = Application.get_env(:realtime_signs, url)

    case download_data(full_url, last_modified) do
      {:ok, _body, new_last_modified} ->
        {new_last_modified || current_time, %{}}

      :error ->
        {last_modified, %{}}
    end
  end

  @spec download_data(String.t(), DateTime.t()) :: {:ok, String.t(), DateTime.t() | nil} | :error
  defp download_data(full_url, last_modified) do
    http_client = Application.get_env(:realtime_signs, :http_client)

    case http_client.get(
           full_url,
           [{"If-Modified-Since", format_last_modified(last_modified)}],
           timeout: 2000,
           recv_timeout: 2000
         ) do
      {:ok, %HTTPoison.Response{body: body, status_code: status, headers: headers}}
      when status >= 200 and status < 300 ->
        with {"Last-Modified", last_modified_string} <-
               Enum.find(headers, fn {header, _value} -> header == "Last-Modified" end),
             {:ok, last_modified_dt} <-
               Timex.parse(last_modified_string, @last_modified_time_format) do
          {:ok, body, last_modified_dt}
        else
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
end
