defmodule Engine.ScheduledHeadways do
  @moduledoc """
  Maintains the current schedules for any gtfs_stop_id that has been registered with this engine.
  Initially we will quickly update any newly registered stop so that we have something to show,
  then over time we will update every stop once every hour to make sure we stay up to date.
  """
  use GenServer
  require Logger
  require Signs.Utilities.SignsConfig

  @type state :: %{
          first_last_departures_ets_table: term(),
          schedule_data: %{String.t() => [map]},
          fetcher: module(),
          fetch_ms: integer(),
          fetch_chunk_size: integer(),
          headway_calc_ms: integer(),
          stop_ids: [String.t()],
          time_fetcher: (-> DateTime.t())
        }

  def start_link(opts \\ []) do
    name = opts[:gen_server_name] || __MODULE__

    GenServer.start_link(
      __MODULE__,
      Keyword.put_new(
        opts,
        :stop_ids,
        Signs.Utilities.SignsConfig.all_train_stop_ids()
      ),
      name: name
    )
  end

  @impl true
  def init(opts) do
    first_last_departures_ets_table =
      opts[:first_last_departures_ets_table] || :scheduled_headways_first_last_departures

    fetcher = opts[:fetcher] || Application.get_env(:realtime_signs, :scheduled_headway_requester)
    fetch_ms = opts[:fetch_ms] || 60 * 60 * 1_000
    fetch_chunk_size = opts[:fetch_chunks_size] || 20
    headway_calc_ms = opts[:headway_calc_ms] || 5 * 60 * 1_000

    time_fetcher =
      opts[:time_fetcher] ||
        fn -> Timex.shift(Timex.now(), milliseconds: div(headway_calc_ms, 2)) end

    ^first_last_departures_ets_table =
      :ets.new(first_last_departures_ets_table, [
        :set,
        :protected,
        :named_table,
        read_concurrency: true
      ])

    state = %{
      first_last_departures_ets_table: first_last_departures_ets_table,
      schedule_data: %{},
      fetcher: fetcher,
      fetch_ms: fetch_ms,
      fetch_chunk_size: fetch_chunk_size,
      headway_calc_ms: headway_calc_ms,
      stop_ids: opts[:stop_ids],
      time_fetcher: time_fetcher
    }

    send(self(), :data_update)

    {:ok, state}
  end

  @spec get_first_last_departures(:ets.tab(), [String.t()]) ::
          [{DateTime.t() | nil, DateTime.t() | nil}]
  def get_first_last_departures(table_name \\ :scheduled_headways_first_last_departures, stop_ids) do
    pattern = for id <- stop_ids, do: {{id, :"$1"}, [], [:"$1"]}
    :ets.select(table_name, pattern)
  end

  @callback get_first_scheduled_departure([binary]) :: nil | DateTime.t()
  def get_first_scheduled_departure(stop_ids) do
    get_first_last_departures(stop_ids)
    |> Enum.map(&elem(&1, 0))
    |> min_time()
  end

  @doc "Checks if the given time is after the first scheduled stop and before the last.
  A buffer of minutes (positive) is subtracted from the first time. so that headways are
  shown for a short time before the first train."
  @callback display_headways?([String.t()], DateTime.t(), Engine.Config.Headway.t()) :: boolean()
  def display_headways?(
        table \\ :scheduled_headways_first_last_departures,
        stop_ids,
        current_time,
        %Engine.Config.Headway{range_high: range_high, range_low: range_low}
      ) do
    first_last_departures = get_first_last_departures(table, stop_ids)

    earliest_first =
      first_last_departures
      |> Enum.map(&elem(&1, 0))
      |> min_time()

    earliest_last =
      first_last_departures
      |> Enum.map(&elem(&1, 1))
      |> min_time()

    case {earliest_first, earliest_last} do
      {%DateTime{} = first, %DateTime{} = last} ->
        first = DateTime.add(first, -1 * (range_high + 1) * 60)
        last = DateTime.add(last, -1 * (range_low - 1) * 60)

        DateTime.compare(current_time, first) == :gt and
          DateTime.compare(current_time, last) == :lt

      _ ->
        false
    end
  end

  @spec min_time([DateTime.t() | nil]) :: DateTime.t() | nil
  defp min_time([]), do: nil
  defp min_time([%DateTime{} = dt]), do: dt

  defp min_time(datetimes) do
    datetimes
    |> Enum.filter(& &1)
    |> Enum.min_by(&DateTime.to_unix/1, fn -> nil end)
  end

  @impl true
  def handle_info(:data_update, state) do
    schedule_data_update(self(), state.fetch_ms)

    {:noreply, update_schedule_data(state)}
  end

  def handle_info(msg, state) do
    Logger.warning("#{__MODULE__} unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  @spec schedule_data_update(pid(), integer()) :: reference()
  defp schedule_data_update(pid, fetch_ms) do
    Process.send_after(pid, :data_update, fetch_ms)
  end

  @spec update_schedule_data(state()) :: state()
  defp update_schedule_data(state) do
    schedule_updater = state[:fetcher]

    updated_schedule_data =
      state.stop_ids
      |> Enum.chunk_every(state.fetch_chunk_size)
      |> Enum.map(fn stop_ids ->
        case schedule_updater.get_schedules(stop_ids) do
          :error ->
            nil

          results ->
            Map.merge(
              Map.new(stop_ids, fn stop_id -> {stop_id, []} end),
              Enum.group_by(results, &get_in(&1, ["relationships", "stop", "data", "id"]))
            )
        end
      end)
      |> Enum.reject(&is_nil(&1))
      |> Enum.reduce(%{}, fn m, acc -> Map.merge(acc, m) end)

    new_schedule_data = Map.merge(state.schedule_data, updated_schedule_data)

    first_last_departures = build_first_last_departures_map(new_schedule_data)
    :ets.insert(state.first_last_departures_ets_table, Map.to_list(first_last_departures))

    Map.put(state, :schedule_data, new_schedule_data)
  end

  @spec build_first_last_departures_map(%{String.t() => [map]}) ::
          %{String.t() => %{first_departure: DateTime.t(), last_departure: DateTime.t()}}
  defp build_first_last_departures_map(schedule_data) do
    stop_time_map = build_stop_time_map(schedule_data)

    Map.new(stop_time_map, fn {stop_id, stop_times} ->
      min_time =
        Enum.reduce(stop_times, nil, fn time, acc ->
          if is_nil(acc) or DateTime.compare(time, acc) == :lt do
            time
          else
            acc
          end
        end)

      max_time =
        Enum.reduce(stop_times, nil, fn time, acc ->
          if is_nil(acc) or DateTime.compare(time, acc) == :gt do
            time
          else
            acc
          end
        end)

      {stop_id, {min_time, max_time}}
    end)
  end

  @spec build_stop_time_map(%{String.t() => [map]}) :: %{
          String.t() => {DateTime.t() | nil, DateTime.t() | nil}
        }
  defp build_stop_time_map(schedule_data) do
    Map.new(schedule_data, fn {stop_id, schedules} ->
      {stop_id,
       Enum.reduce(schedules, [], fn sched, acc ->
         departure_time =
           get_in(sched, ["attributes", "departure_time"]) ||
             get_in(sched, ["attributes", "arrival_time"])

         with false <- is_nil(departure_time),
              {:ok, parsed_time} <- Timex.parse(departure_time, "{ISO:Extended}") do
           [parsed_time | acc]
         else
           _ -> acc
         end
       end)}
    end)
  end
end
