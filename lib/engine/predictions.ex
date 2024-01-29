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

  defstruct last_modified: nil,
            trip_updates_table: :trip_updates,
            revenue_vehicles_table: :revenue_vehicles

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "The upcoming predicted times a vehicle will be at this stop"
  @impl true
  def for_stop(predictions_table_id \\ :trip_updates, gtfs_stop_id, direction_id) do
    case :ets.lookup(predictions_table_id, {gtfs_stop_id, direction_id}) do
      [{{^gtfs_stop_id, ^direction_id}, predictions}] -> predictions
      _ -> []
    end
  end

  @impl true
  def revenue_vehicles() do
    case :ets.lookup(:revenue_vehicles, :all) do
      [{:all, data}] -> data
      _ -> MapSet.new()
    end
  end

  @impl true
  def init(_) do
    schedule_update(self())
    :ets.new(:trip_updates, [:named_table, read_concurrency: true])
    :ets.new(:revenue_vehicles, [:named_table, read_concurrency: true])
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_info(:update, %__MODULE__{last_modified: last_modified} = state) do
    schedule_update(self())
    current_time = Timex.now()
    http_client = Application.get_env(:realtime_signs, :http_client)

    new_last_modified =
      case http_client.get(
             Application.get_env(:realtime_signs, :trip_update_url),
             if(last_modified, do: [{"If-Modified-Since", last_modified}], else: []),
             timeout: 2000,
             recv_timeout: 2000
           ) do
        {:ok, %HTTPoison.Response{body: body, status_code: 200, headers: headers}} ->
          {new_predictions, vehicles_running_revenue_trips} =
            Predictions.Predictions.parse_json_response(body)
            |> Predictions.Predictions.get_all(current_time)

          :ets.tab2list(state.trip_updates_table)
          |> Enum.map(&{elem(&1, 0), []})
          |> Map.new()
          |> Map.merge(new_predictions)
          |> Map.to_list()
          |> then(&:ets.insert(state.trip_updates_table, &1))

          :ets.insert(state.revenue_vehicles_table, {:all, vehicles_running_revenue_trips})

          Enum.find_value(headers, fn {key, value} -> if(key == "Last-Modified", do: value) end)

        {:ok, %HTTPoison.Response{status_code: 304}} ->
          last_modified

        {_, response} ->
          Logger.warn("Could not fetch predictions: #{inspect(response)}")
          last_modified
      end

    {:noreply, %{state | last_modified: new_last_modified}}
  end

  def handle_info(msg, state) do
    Logger.info("#{__MODULE__} unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end
end
