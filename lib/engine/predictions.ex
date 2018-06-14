defmodule Engine.Predictions do
  @moduledoc """
  Maintains an up-to-date internal state of the realtime predictions of vehicles
  in the system. Fetches from the GTFS-RT PB file about once per second.

  Offers a `for_stop/1` public interface to get a list of Predictions.Prediction's
  for a given GTFS stop.
  """

  use GenServer
  require Logger

  @predictions_table :vehicle_predictions
  @positions_table :vehicle_positions

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "The upcoming predicted times a vehicle will be at this stop"
  @spec for_stop(String.t(), 0 | 1) :: [Predictions.Prediction.t()]
  def for_stop(predictions_table_id \\ @predictions_table, gtfs_stop_id, direction_id) do
    case :ets.lookup(predictions_table_id, {gtfs_stop_id, direction_id}) do
      [{{^gtfs_stop_id, ^direction_id}, predictions}] -> predictions
      _ -> []
    end
  end

  @doc "determines if this stop is currently boarding"
  @spec currently_boarding?(String.t()) :: boolean()
  def currently_boarding?(positions_table_id \\ @positions_table, gtfs_stop_id) do
    case :ets.lookup(positions_table_id, gtfs_stop_id) do
      [{^gtfs_stop_id, true}] -> true
      _ -> false
    end
  end

  @spec init(any()) :: {:ok, any()}
  def init(_) do
    schedule_update(self())
    @predictions_table = :ets.new(@predictions_table, [:set, :protected, :named_table, read_concurrency: true])
    @positions_table = :ets.new(@positions_table, [:set, :protected, :named_table, read_concurrency: true])
    {:ok, {Timex.now(), Timex.now()}}
  end

  @spec handle_info(:update, {DateTime.t, DateTime.t}) :: {:noreply, {DateTime.t, DateTime.t}}
  def handle_info(:update, {last_modified_predictions, last_modified_positions}) do
    schedule_update(self())
    current_time = Timex.now()
    last_modified_predictions = get_last_modified(last_modified_predictions, current_time, &update_predictions/2, :trip_update_url)
    last_modified_positions = get_last_modified(last_modified_positions, current_time, &update_positions/2, :vehicle_positions_url)
    {:noreply, {last_modified_predictions, last_modified_positions}}
  end

  defp format_last_modified(time) do
    {:ok, last_modified} = Timex.format(time, "{WDshort}, {D} {Mshort} {YYYY} {h24}:{m}:{s} {Zabbr}")
    last_modified
  end

  defp update_predictions(body, current_time) do
    new_predictions = body
                      |> Predictions.Predictions.parse_pb_response()
                      |> Predictions.Predictions.get_all(current_time)
    :ets.delete_all_objects(@predictions_table)
    :ets.insert(@predictions_table, Enum.into(new_predictions, []))
  end

  defp update_positions(body, _current_time) do
    new_positions = body
                      |> Positions.Positions.parse_pb_response()
                      |> Positions.Positions.get_all()
    :ets.delete_all_objects(@positions_table)
    :ets.insert(@positions_table, new_positions)
  end

  defp get_last_modified(last_modified, current_time, parse_fn, url) do
    http_client = Application.get_env(:realtime_signs, :http_client)
    full_url = Application.get_env(:realtime_signs, url)
    case http_client.get(full_url, [{"If-Modified-Since", format_last_modified(last_modified)}]) do
      {:ok, %HTTPoison.Response{body: body, status_code: status}} when status >= 200 and status < 300 ->
        parse_fn.(body, current_time)
        current_time
      {:ok, %HTTPoison.Response{}} ->
        last_modified
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("Could not fetch pb file from #{inspect full_url}: #{inspect reason}")
        last_modified
    end
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end
end
