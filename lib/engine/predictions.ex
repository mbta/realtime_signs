defmodule Engine.Predictions do
  @moduledoc """
  Maintains an up-to-date internal state of the realtime predictions of vehicles
  in the system. Fetches from the GTFS-rt enhanced JSON file about once per
  second.

  Offers a `for_stop/1` public interface to get a list of Predictions.Prediction's
  for a given GTFS stop.
  """
  @behaviour Engine.PredictionsAPI

  use GenServer
  require Logger

  @type state :: %{
          last_modified_trip_updates: String.t() | nil,
          trip_updates_table: :ets.tab()
        }

  @trip_updates_table :trip_updates

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "The upcoming predicted times a vehicle will be at this stop"
  @impl true
  def for_stop(predictions_table_id \\ @trip_updates_table, gtfs_stop_id, direction_id) do
    case :ets.lookup(predictions_table_id, {gtfs_stop_id, direction_id}) do
      [{_, :none}] -> []
      [{{^gtfs_stop_id, ^direction_id}, predictions}] -> predictions
      _ -> []
    end
  end

  @impl true
  def init(_) do
    schedule_update(self())

    @trip_updates_table =
      :ets.new(@trip_updates_table, [:set, :protected, :named_table, read_concurrency: true])

    {:ok,
     %{
       last_modified_trip_updates: nil,
       trip_updates_table: @trip_updates_table
     }}
  end

  @impl true
  def handle_info(:update, state) do
    schedule_update(self())
    current_time = Timex.now()

    {last_modified_trip_updates, vehicles_running_revenue_trips} =
      download_and_process_trip_updates(
        state[:last_modified_trip_updates],
        current_time,
        :trip_update_url,
        state[:trip_updates_table]
      )

    if vehicles_running_revenue_trips != nil do
      {:noreply, %{state | last_modified_trip_updates: last_modified_trip_updates}}
    else
      {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    Logger.info("#{__MODULE__} unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  @spec download_and_process_trip_updates(
          String.t() | nil,
          DateTime.t(),
          atom,
          :ets.tab()
        ) :: {String.t() | nil, any()}
  defp download_and_process_trip_updates(
         last_modified,
         current_time,
         url,
         ets_table
       ) do
    full_url = Application.get_env(:realtime_signs, url)

    case download_data(full_url, last_modified) do
      {:ok, body, new_last_modified} ->
        {new_predictions, vehicles_running_revenue_trips} =
          body
          |> Predictions.Predictions.parse_json_response()
          |> Predictions.Predictions.get_all(current_time)

        existing_predictions =
          :ets.tab2list(ets_table) |> Enum.map(&{elem(&1, 0), :none}) |> Map.new()

        all_predictions = Map.merge(existing_predictions, new_predictions)
        :ets.insert(ets_table, Enum.into(all_predictions, []))

        {new_last_modified, vehicles_running_revenue_trips}

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
end
