defmodule Engine.LastTrip do
  @behaviour Engine.LastTripAPI
  use GenServer
  require Logger

  @recent_departures_table :recent_departures
  @last_trips_table :last_trips

  @type state :: %{
          last_modified: nil,
          recent_departures: :ets.tab(),
          last_trips: :ets.tab()
        }

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def get_recent_departures(stop_id) do
    # Look up stop_id in recent departures table for recently departed trips
    # Then see if any of those trips have a last trip record
  end

  @impl true
  def get_last_trips(stop_id) do
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

    # Update recent departures and last trips tables
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

            :ets.insert(state.last_trips, {"123", Timex.now() |> Timex.shift(minutes: -30)})
            :ets.insert(state.last_trips, {"456", Timex.now() |> Timex.shift(minutes: -70)})
          end)
          |> Enum.map(&{&1["trip"]["trip_id"], &1["stop_time_update"]})
          |> tap(fn predictions_by_trip ->
            for {trip_id, predictions} <- predictions_by_trip,
                prediction <- predictions,
                prediction["departure"] do
              seconds_until_departure =
                prediction["departure"]["time"] - DateTime.to_unix(current_time)

              if seconds_until_departure <= 0 and abs(seconds_until_departure) <= 3600 do
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

                # :ets.insert(
                #   state.recent_departures,
                #   {prediction["stop_id"], %{trip_id: trip_id, timestamp: current_time}}
                # )
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

    :ets.tab2list(state.last_trips)
    |> Enum.filter(fn {_, timestamp} ->
      Timex.diff(Timex.now(), timestamp, :seconds) > 3600
    end)
    |> Enum.each(fn {trip_id, _} ->
      :ets.delete(state.last_trips, trip_id)
    end)

    {:noreply, state}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end

  defp schedule_clean(pid) do
    Process.send_after(pid, :clean_old_data, 1_000)
  end
end
