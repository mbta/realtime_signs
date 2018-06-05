defmodule Engine.Predictions do
  @moduledoc """
  Maintains an up-to-date internal state of the realtime predictions of vehicles
  in the system. Fetches from the GTFS-RT PB file about once per second.

  Offers a `for_stop/1` public interface to get a list of Predictions.Prediction's
  for a given GTFS stop.
  """

  use GenServer
  require Logger

  @table __MODULE__

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "The upcoming predicted times a vehicle will be at this stop"
  @spec for_stop(String.t(), 0 | 1) :: [Predictions.Prediction.t()]
  def for_stop(gtfs_stop_id, direction_id) do
    case :ets.lookup(@table, {gtfs_stop_id, direction_id}) do
      [{{^gtfs_stop_id, ^direction_id}, predictions}] -> predictions
      _ -> []
    end
  end

  @spec init(any()) :: {:ok, any()}
  def init(_) do
    schedule_update(self())
    @table = :ets.new(__MODULE__, [:set, :protected, :named_table, read_concurrency: true])
    {:ok, Timex.now()}
  end

  @spec handle_info(:update, DateTime.t) :: {:noreply, DateTime.t}
  def handle_info(:update, last_modified) do
    schedule_update(self())
    current_time = Timex.now()
    {:ok, modified_since} = last_modified |> Timex.format("{WDshort}, {D} {Mshort} {YYYY} {h24}:{m}:{s} {Zabbr}")
    http_client = Application.get_env(:realtime_signs, :http_client)
    last_modified = case Application.get_env(:realtime_signs, :trip_update_url) |> http_client.get([{"If-Modified-Since", modified_since}]) do
      {:ok, %HTTPoison.Response{body: body, status_code: status}} when status >= 200 and status < 300 ->
        new_predictions = body
        |> Predictions.Predictions.parse_pb_response()
        |> Predictions.Predictions.get_all(current_time)
        :ets.delete_all_objects(@table)
        :ets.insert(@table, Enum.into(new_predictions, []))
        current_time
      {:ok, %HTTPoison.Response{}} ->
        last_modified
      {:error, reason} ->
        Logger.warn("Could not fetch pb file: #{inspect reason}")
        last_modified
    end
    {:noreply, last_modified}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end
end
