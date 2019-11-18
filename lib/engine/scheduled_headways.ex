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
          headways_ets_table: term(),
          first_last_departures_ets_table: term(),
          schedule_data: %{String.t() => [Headway.HeadwayDisplay.schedule_map()]},
          fetcher: module(),
          fetch_ms: integer(),
          fetch_chunk_size: integer(),
          headway_calc_ms: integer(),
          stop_ids: [String.t()],
          time_fetcher: (() -> DateTime.t())
        }

  def start_link(opts \\ []) do
    name = opts[:gen_server_name] || __MODULE__

    GenServer.start_link(
      __MODULE__,
      Keyword.put_new(
        opts,
        :stop_ids,
        Signs.Utilities.SignsConfig.all_stop_ids()
      ),
      name: name
    )
  end

  @spec init(Keyword.t()) :: {:ok, state()}
  def init(opts) do
    headways_ets_table = opts[:headways_ets_table] || :scheduled_headways

    first_last_departures_ets_table =
      opts[:first_last_departures_ets_table] || :scheduled_headways_first_last_departures

    fetcher = opts[:fetcher] || Application.get_env(:realtime_signs, :scheduled_headway_requester)
    fetch_ms = opts[:fetch_ms] || 60 * 60 * 1_000
    fetch_chunk_size = opts[:fetch_chunks_size] || 20
    headway_calc_ms = opts[:headway_calc_ms] || 5 * 60 * 1_000

    time_fetcher =
      opts[:time_fetcher] ||
        fn -> Timex.shift(Timex.now(), milliseconds: div(headway_calc_ms, 2)) end

    ^headways_ets_table =
      :ets.new(headways_ets_table, [:set, :protected, :named_table, read_concurrency: true])

    ^first_last_departures_ets_table =
      :ets.new(first_last_departures_ets_table, [
        :set,
        :protected,
        :named_table,
        read_concurrency: true
      ])

    state = %{
      headways_ets_table: headways_ets_table,
      first_last_departures_ets_table: first_last_departures_ets_table,
      schedule_data: %{},
      fetcher: fetcher,
      fetch_ms: fetch_ms,
      fetch_chunk_size: fetch_chunk_size,
      headway_calc_ms: headway_calc_ms,
      stop_ids: opts[:stop_ids],
      time_fetcher: time_fetcher
    }

    :ets.insert(headways_ets_table, Enum.map(state.stop_ids, fn x -> {x, :none} end))

    send(self(), :data_update)
    send(self(), :calculation_update)

    {:ok, state}
  end

  @spec get_headways(:ets.tab(), String.t()) :: Headway.HeadwayDisplay.headway_range()
  def get_headways(table_name \\ :scheduled_headways, stop_id) do
    [{_stop_id, headways}] = :ets.lookup(table_name, stop_id)

    headways
  end

  @spec get_first_last_departures(:ets.tab(), String.t()) ::
          {DateTime.t() | nil, DateTime.t() | nil}
  def get_first_last_departures(table_name \\ :scheduled_headways_first_last_departures, stop_id) do
    case :ets.lookup(table_name, stop_id) do
      [{^stop_id, {first_departure, last_departure}}] -> {first_departure, last_departure}
      _ -> {nil, nil}
    end
  end

  @spec handle_info(:data_update, state) :: {:noreply, state}
  def handle_info(:data_update, state) do
    schedule_data_update(self(), state.fetch_ms)

    {:noreply, update_schedule_data(state)}
  end

  def handle_info(:calculation_update, state) do
    schedule_calculation_update(self(), state.headway_calc_ms)

    {:noreply, update_headway_data(state)}
  end

  def handle_info(msg, state) do
    Logger.warn("#{__MODULE__} unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  @spec schedule_data_update(pid(), integer()) :: reference()
  defp schedule_data_update(pid, fetch_ms) do
    Process.send_after(pid, :data_update, fetch_ms)
  end

  @spec schedule_calculation_update(pid(), integer()) :: reference()
  defp schedule_calculation_update(pid, headway_calc_ms) do
    Process.send_after(pid, :calculation_update, headway_calc_ms)
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

  @spec update_headway_data(state()) :: state()
  defp update_headway_data(state) do
    headway_calculator = Application.get_env(:realtime_signs, :headway_calculator)

    headways =
      headway_calculator.group_headways_for_stations(
        state.schedule_data,
        state.stop_ids,
        state.time_fetcher.()
      )

    headways =
      state.stop_ids
      |> Enum.map(fn x -> {x, :none} end)
      |> Map.new()
      |> Map.merge(headways)

    :ets.insert(state.headways_ets_table, headways |> Enum.into([]))

    state
  end

  @spec build_first_last_departures_map(%{String.t() => [Headway.HeadwayDisplay.schedule_map()]}) ::
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

  @spec build_stop_time_map(%{String.t() => [Headway.HeadwayDisplay.schedule_map()]}) :: %{
          String.t() => {DateTime.t() | nil, DateTime.t() | nil}
        }
  defp build_stop_time_map(schedule_data) do
    Map.new(schedule_data, fn {stop_id, schedules} ->
      {stop_id,
       Enum.reduce(schedules, [], fn sched, acc ->
         departure_time = get_in(sched, ["attributes", "departure_time"])

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
