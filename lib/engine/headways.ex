defmodule Engine.Headways do
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
          schedule_data: map(),
          fetcher: module(),
          fetch_ms: integer(),
          headway_calc_ms: integer(),
          stop_ids: [String.t()]
        }

  def start_link do
    GenServer.start_link(
      __MODULE__,
      [stop_ids: Signs.Utilities.SignsConfig.all_stop_ids()],
      name: __MODULE__
    )
  end

  @spec init(Keyword.t()) :: {:ok, state()}
  def init(opts) do
    ets_table_name = opts[:ets_table_name] || __MODULE__
    fetcher = opts[:fetcher] || Application.get_env(:realtime_signs, :headway_requester)
    fetch_ms = opts[:fetch_ms] || 60 * 60 * 1_000
    headway_calc_ms = opts[:headway_calc_ms] || 5 * 60 * 1_000

    ^ets_table_name =
      :ets.new(ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

    state = %{
      ets_table_name: ets_table_name,
      schedule_data: %{},
      fetcher: fetcher,
      fetch_ms: fetch_ms,
      headway_calc_ms: headway_calc_ms,
      stop_ids: opts[:stop_ids]
    }

    :ets.insert(ets_table_name, Enum.map(state.stop_ids, fn x -> {x, :none} end))

    send(self(), :update_hourly)
    send(self(), :headway_update)

    {:ok, state}
  end

  @spec get_headways(:ets.tab(), String.t()) :: Headway.ScheduleHeadway.headway_range() | :none
  def get_headways(table_name \\ __MODULE__, stop_id) do
    [{_stop_id, headways}] = :ets.lookup(table_name, stop_id)

    headways
  end

  @spec handle_info(:update_hourly, t) :: {:noreply, t}
  def handle_info(:update_hourly, state) do
    schedule_update(self(), state)

    update_schedule_data(state)
  end

  def handle_info(:headway_update, state) do
    headway_update(self(), state)

    update_headway_data(state)
  end

  def handle_info(msg, state) do
    Logger.warn("#{__MODULE__} unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  @spec schedule_update(pid(), state()) :: reference()
  defp schedule_update(pid, state) do
    Process.send_after(pid, :update_hourly, state.fetch_ms)
  end

  @spec headway_update(pid(), state()) :: reference()
  defp headway_update(pid, state) do
    Process.send_after(pid, :headway_update, state.headway_calc_ms)
  end

  @spec update_schedule_data(state()) :: {:noreply, state()}
  defp update_schedule_data(state) do
    schedule_updater = state[:fetcher]

    Map.put(
      state,
      :schedule_data,
      state.stop_ids
      |> schedule_updater.get_schedules()
      |> Enum.group_by(fn schedule ->
        schedule["relationships"]["stop"]["data"]["id"]
      end)
    )

    {:noreply, state}
  end

  @spec update_headway_data(state()) :: {:noreply, state()}
  defp update_headway_data(state) do
    headway_calculator = Application.get_env(:realtime_signs, :headway_calculator)

    headways =
      Enum.map(
        headway_calculator.group_headways_for_stations(
          state.schedule_data,
          state.stop_ids,
          Timex.now()
        ),
        fn {k, v} -> {k, v} end
      )

    :ets.delete_all_objects(state.ets_table_name)
    :ets.insert(state.ets_table_name, headways)

    {:noreply, state}
  end
end
