defmodule Engine.Headways do
  @moduledoc """
  Maintains the current schedules for any gtfs_stop_id that has been registered with this engine.
  Initially we will quickly update any newly registered stop so that we have something to show,
  then over time we will update every stop once every hour to make sure we stay up to date.
  """
  use GenServer
  require Logger

  @type t :: %{
          String.t() => [Headway.ScheduleHeadway.schedule_map()]
        }

  @type state :: %{
          ets_table_name: term(),
          fetcher: module(),
          fetch_ms: integer(),
          stop_ids: [String.t()]
        }

  def start_link do
    GenServer.start_link(__MODULE__, [stop_ids: all_stop_ids()], name: __MODULE__)
  end

  @spec all_stop_ids() :: [String.t()]
  defp all_stop_ids do
    json_data =
      :realtime_signs
      |> :code.priv_dir()
      |> Path.join("signs.json")
      |> File.read!()
      |> Poison.Parser.parse!()

    Enum.map(json_data, fn x -> Map.get(x, "source_config") end)
    |> List.flatten()
    |> Enum.reject(fn x -> x == nil end)
    |> Enum.map(fn x -> Map.get(x, "stop_id") end)
  end

  @spec init(Keyword.t()) :: {:ok, state()}
  def init(opts) do
    fetch_ms = opts[:fetch_ms] || 60 * 60 * 1_000
    fetcher = opts[:fetcher] || Application.get_env(:realtime_signs, :headway_requester)
    ets_table_name = opts[:ets_table_name] || __MODULE__

    ^ets_table_name =
      :ets.new(ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

    state = %{
      ets_table_name: ets_table_name,
      fetcher: fetcher,
      fetch_ms: fetch_ms,
      stop_ids: opts[:stop_ids]
    }

    schedule_update(self(), state)

    {:ok, state}
  end

  @spec get_headways(GenServer.server(), String.t()) :: Headway.ScheduleHeadway.headway_range()
  def get_headways(pid \\ __MODULE__, stop_id) do
    GenServer.call(pid, {:get_headways, stop_id})
  end

  @spec handle_info(:update_hourly, t) :: {:noreply, t}
  def handle_info(:update_hourly, state) do
    schedule_update(self(), state)

    update(state)
  end

  def handle_info(msg, state) do
    Logger.warn("#{__MODULE__} unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  @spec handle_call({:get_headways, String.t()}, GenServer.from(), state()) ::
          {:reply, Headway.ScheduleHeadway.headway_range(), state()} | {:noreply, state}
  def handle_call({:get_headways, stop_id}, _from, state) do
    case :ets.lookup(state.ets_table_name, stop_id) do
      [{_stop_id, headways}] -> {:reply, headways, state}
      _ -> {:noreply, state}
    end
  end

  @spec schedule_update(pid(), state()) :: reference()
  defp schedule_update(pid, state) do
    Process.send_after(pid, :update_hourly, state.fetch_ms)
  end

  @spec update(state()) :: {:noreply, state()}
  defp update(state) do
    headway_updater = state[:fetcher]
    headway_calculator = Application.get_env(:realtime_signs, :headway_calculator)

    schedules =
      state.stop_ids
      |> headway_updater.get_schedules()
      |> Enum.group_by(fn schedule ->
        schedule["relationships"]["stop"]["data"]["id"]
      end)

    # TODO: We should figure out what to do about the current time issue
    headways =
      Enum.map(
        headway_calculator.group_headways_for_stations(schedules, state.stop_ids, Timex.now()),
        fn {k, v} -> {k, v} end
      )

    :ets.delete_all_objects(state.ets_table_name)
    :ets.insert(state.ets_table_name, headways)

    {:noreply, state}
  end
end
