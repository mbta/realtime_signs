defmodule Engine.LastTrip do
  @behaviour Engine.LastTripAPI
  use GenServer
  require Logger

  @recent_departures_table :recent_departures
  @last_trips_table :last_trips
  @hour_in_seconds 3600

  @type state :: %{
          last_modified: nil,
          recent_departures: :ets.tab(),
          last_trips: :ets.tab()
        }

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def get_recent_departures(recent_departures_table \\ @recent_departures_table, stop_id) do
    case :ets.lookup(recent_departures_table, stop_id) do
      [{_, :none}] -> nil
      [{^stop_id, departures}] -> departures
      _ -> nil
    end
  end

  @impl true
  def get_last_trips(last_trips_table \\ @last_trips_table, stop_id) do
    case :ets.lookup(last_trips_table, stop_id) do
      [{_, :none}] -> nil
      [{^stop_id, last_trips}] -> last_trips
      _ -> nil
    end
  end

  @impl true
  def init(_) do
    schedule_update(self())
    schedule_clean(self())

    state = %{
      recent_departures: @recent_departures_table,
      last_trips: @last_trips_table,
      last_modified: nil
    }

    create_tables(state)
    {:ok, state}
  end

  def create_tables(state) do
    :ets.new(state.recent_departures, [:named_table, read_concurrency: true])
    :ets.new(state.last_trips, [:named_table, read_concurrency: true])
  end

  @impl true
  def handle_info(:update, %{last_modified: last_modified} = state) do
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
          predictions_feed = Predictions.Predictions.parse_json_response(body)

          predictions_feed["entity"]
          |> Enum.map(& &1["trip_update"])
          |> Enum.reject(&(&1["trip"]["schedule_relationship"] == "CANCELED"))
          |> tap(fn trips ->
            Enum.filter(trips, &(&1["trip"]["last_trip"] == true))
            |> Enum.map(&{&1["trip"]["trip_id"], current_time})
            |> Enum.each(fn {trip_id, timestamp} ->
              :ets.insert(state.last_trips, {trip_id, timestamp})
            end)
          end)
          |> Enum.map(&{&1["trip"]["trip_id"], &1["stop_time_update"]})
          |> tap(fn predictions_by_trip ->
            for {trip_id, predictions} <- predictions_by_trip,
                prediction <- predictions,
                prediction["departure"] do
              seconds_until_departure =
                prediction["departure"]["time"] - DateTime.to_unix(current_time)

              if seconds_until_departure <= 0 and abs(seconds_until_departure) <= @hour_in_seconds do
                :ets.tab2list(state.recent_departures)
                |> Enum.map(&{elem(&1, 0), elem(&1, 1)})
                |> Map.new()
                |> Map.get_and_update(prediction["stop_id"], fn recent_departures ->
                  if recent_departures do
                    {recent_departures,
                     Map.put(recent_departures, trip_id, prediction["departure"]["time"])}
                  else
                    {recent_departures, Map.new([{trip_id, prediction["departure"]["time"]}])}
                  end
                end)
                |> elem(1)
                |> Map.to_list()
                |> then(&:ets.insert(state.recent_departures, &1))
              end
            end
          end)

          Enum.find_value(headers, fn {key, value} -> if(key == "Last-Modified", do: value) end)

        {:ok, %HTTPoison.Response{status_code: 304}} ->
          last_modified

        {_, response} ->
          Logger.warn("Could not fetch predictions: #{inspect(response)}")
          last_modified
      end

    {:noreply, %{state | last_modified: new_last_modified}}
  end

  @impl true
  def handle_info(:clean_old_data, state) do
    schedule_clean(self())
    clean_last_trips(state)
    clean_recent_departures(state)

    {:noreply, state}
  end

  defp clean_last_trips(state) do
    :ets.tab2list(state.last_trips)
    |> Enum.each(fn {trip_id, timestamp} ->
      if Timex.diff(Timex.now(), timestamp, :seconds) > @hour_in_seconds do
        :ets.delete(state.last_trips, trip_id)
      else
        :ok
      end
    end)
  end

  defp clean_recent_departures(state) do
    current_time = Timex.now()

    :ets.tab2list(state.recent_departures)
    |> Enum.each(fn {stop_id, departures} ->
      departures_within_last_hour =
        Enum.filter(departures, fn {_, departed_time} ->
          DateTime.to_unix(current_time) - departed_time <= @hour_in_seconds
        end)
        |> Map.new()

      :ets.insert(state.recent_departures, {stop_id, departures_within_last_hour})
    end)
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end

  defp schedule_clean(pid) do
    Process.send_after(pid, :clean_old_data, 1_000)
  end
end
