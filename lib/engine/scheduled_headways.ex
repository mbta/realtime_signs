defmodule Engine.ScheduledHeadways do
  @moduledoc """
  Maintains the current schedules for any gtfs_stop_id that has been registered with this engine.
  Initially we will quickly update any newly registered stop so that we have something to show,
  then over time we will update every stop once every hour to make sure we stay up to date.
  """
  use GenServer
  require Logger
  require Signs.Utilities.SignsConfig

  @type t :: %{
          String.t() => [Headway.ScheduleHeadway.schedule_map()]
        }

  @type state :: %{
          ets_table_name: term(),
          schedule_data: list(),
          fetcher: module(),
          fetch_ms: integer(),
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
    ets_table_name = opts[:ets_table_name] || __MODULE__
    fetcher = opts[:fetcher] || Application.get_env(:realtime_signs, :scheduled_headway_requester)
    fetch_ms = opts[:fetch_ms] || 60 * 60 * 1_000
    headway_calc_ms = opts[:headway_calc_ms] || 5 * 60 * 1_000

    time_fetcher =
      opts[:time_fetcher] ||
        fn -> Timex.shift(Timex.now(), milliseconds: div(headway_calc_ms, 2)) end

    ^ets_table_name =
      :ets.new(ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

    state = %{
      ets_table_name: ets_table_name,
      schedule_data: [],
      fetcher: fetcher,
      fetch_ms: fetch_ms,
      headway_calc_ms: headway_calc_ms,
      stop_ids: opts[:stop_ids],
      time_fetcher: time_fetcher
    }

    :ets.insert(ets_table_name, Enum.map(state.stop_ids, fn x -> {x, :none} end))

    send(self(), :data_update)
    send(self(), :calculation_update)

    {:ok, state}
  end

  @spec get_headways(:ets.tab(), String.t()) :: Headway.ScheduleHeadway.headway_range()
  def get_headways(table_name \\ __MODULE__, stop_id) do
    [{_stop_id, headways}] = :ets.lookup(table_name, stop_id)

    headways
  end

  @spec handle_info(:data_update, t) :: {:noreply, t}
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

    new_schedule_raw =
      state.stop_ids
      |> Enum.chunk_every(20)
      |> Enum.map(&schedule_updater.get_schedules(&1))

    new_schedule =
      case Enum.any?(new_schedule_raw, &(&1 == [])) do
        true -> []
        false -> Enum.concat(new_schedule_raw)
      end

    case new_schedule do
      [] ->
        state

      schedule ->
        Map.put(
          state,
          :schedule_data,
          schedule
        )
    end
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

    :ets.insert(state.ets_table_name, headways |> Enum.into([]))

    state
  end
end
