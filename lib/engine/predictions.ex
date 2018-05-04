defmodule Engine.Predictions do
  @moduledoc """
  Maintains an up-to-date internal state of the realtime predictions of vehicles
  in the system. Fetches from the GTFS-RT PB file about once per second.

  Offers a `for_stop/1` public interface to get a list of Predictions.Prediction's
  for a given GTFS stop.
  """

  use GenServer
  require Logger

  @type t :: {DateTime.t, %{
    String.t() => [Predictions.Prediction.t()]
  }}

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "The upcoming predicted times a vehicle will be at this stop"
  @spec for_stop(GenServer.server(), String.t(), 0 | 1) :: [Predictions.Prediction.t()]
  def for_stop(pid \\ __MODULE__, gtfs_stop_id, direction_id) do
    GenServer.call(pid, {:for_stop, gtfs_stop_id, direction_id})
  end

  @spec init(any()) :: {:ok, any()}
  def init(_) do
    schedule_update(self())
    {:ok, {Timex.now(), %{}}}
  end

  @spec handle_call({:for_stop, String.t(), 0 | 1}, GenServer.from(), t()) :: {:reply, [Predictions.Prediction.t()], t()}
  def handle_call({:for_stop, gtfs_stop_id, direction_id}, _from, {_last_modified, predictions} = state) do
    {:reply, Map.get(predictions, {gtfs_stop_id, direction_id}, []), state}
  end

  @spec handle_info(:update, t()) :: {:noreply, t()}
  def handle_info(:update, {last_modified, current_predictions}) do
    schedule_update(self())
    current_time = Timex.now()
    {:ok, modified_since} = last_modified |> Timex.format("{WDshort}, {D} {Mshort} {YYYY} {h24}:{m}:{s} {Zabbr}")
    http_client = Application.get_env(:realtime_signs, :http_client)
    updated_state = case Application.get_env(:realtime_signs, :trip_update_url) |> http_client.get([{"If-Modified-Since", modified_since}]) do
      {:ok, %HTTPoison.Response{body: body, status_code: status}} when status >= 200 and status < 300 ->
        new_predictions = body
        |> Predictions.Predictions.parse_pb_response()
        |> Predictions.Predictions.get_all(current_time)
        {current_time, new_predictions}
      {:ok, %HTTPoison.Response{}} ->
        {last_modified, current_predictions}
      {:error, reason} ->
        Logger.warn("Could not fetch pb file: #{inspect reason}")
        {last_modified, current_predictions}
    end
    {:noreply, updated_state}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end
end
