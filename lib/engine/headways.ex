defmodule Engine.Headways do
  @moduledoc """
  Maintains the current schedules for any gtfs_stop_id that has been registered with this engine.
  Initially we will quickly update any newly registered stop so that we have something to show,
  then over time we will update every stop once every hour to make sure we stay up to date.
  """
  use GenServer
  require Logger
  alias Headway.ScheduleHeadway

  @type t :: %{
    String.t => [Headway.ScheduleHeadway.schedule_map]
  }

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    schedule_update(self())
    {:ok, %{}}
  end

  @spec register(GenServer.server(), String.t()) :: :ok
  def register(pid \\ __MODULE__, gtfs_stop_id) do
    GenServer.call(pid, {:register, gtfs_stop_id})
  end

  @spec get_headways(GenServer.server(), String.t()) :: Headway.ScheduleHeadway.headway_range
  def get_headways(pid \\ __MODULE__, stop_id) do
    GenServer.call(pid, {:get_headways, stop_id, Timex.now()})
  end

  @spec handle_info(:quick_update, t) :: {:noreply, t}
  def handle_info(:quick_update, state) do
    state
    |> Enum.reject(fn {_stop, schedule} -> schedule != [] end)
    |> Map.new
    |> Map.keys
    |> update(state)
  end

  @spec handle_info(:update_hourly, t) :: {:noreply, t}
  def handle_info(:update_hourly, state) do
    schedule_update(self())

    state
    |> Map.keys
    |> update(state)
  end

  @spec handle_call({:get_headways, String.t(), DateTime.t}, GenServer.from(), t()) :: {:reply, Headway.ScheduleHeadway.headway_range, t()}
  def handle_call({:get_headways, stop_id, current_time}, _from, state) do
    headway_calculator = Application.get_env(:realtime_signs, :headway_calculator)
    schedules = state[stop_id]
    {:reply, Map.get(headway_calculator.group_headways_for_stations(schedules, [stop_id], current_time), stop_id), state}
  end
  @spec handle_call({:register, String.t()}, GenServer.from(), t()) :: {:reply, t(), t()}
  def handle_call({:register, gtfs_stop_id}, _from, state) do
    state = Map.put(state, gtfs_stop_id, [])
    quick_update(self())
    {:reply, :ok, state}
  end

  defp quick_update(pid) do
    Process.send_after(pid, :quick_update, 10_000)
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update_hourly, 60 * 60 * 1_000)
  end

  defp update([], state) do
    {:noreply, state}
  end
  defp update(stops, state) do
    headway_updater = Application.get_env(:realtime_signs, :headway_requester)
    schedules = stops
                |> headway_updater.get_schedules()
                |> Enum.group_by(fn schedule ->
                  schedule["relationships"]["stop"]["data"]["id"]
                end)
    schedules = Map.merge(state, schedules)

    {:noreply, schedules}
  end
end
