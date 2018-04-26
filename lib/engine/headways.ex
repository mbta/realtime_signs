defmodule Engine.Headways do
  use GenServer
  require Logger
  alias Headway.ScheduleHeadway

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    {:ok, %{}}
  end

  def register(pid \\ __MODULE__, gtfs_stop_id) do
    schedule_update(pid)
    GenServer.call(pid, {:register, gtfs_stop_id})
  end

  def update_headways(pid \\ __MODULE__) do
    GenServer.call(pid, {:update_headways})
  end

  def get_headways(pid \\ __MODULE__, stop_id) do
    GenServer.call(pid, {:get_headways, stop_id, Timex.now()})
  end

  def handle_info(:update_headways, state) do
    stops = state
            |> Enum.reject(fn {stop, schedule} -> schedule != [] end)
            |> Map.new
            |> Map.keys

    case stops do
      [] ->
        {:noreply, state}
      _ ->
        schedules = Headway.Request.get_schedules(stops)
        |> Enum.group_by(state, fn schedule ->
          schedule["relationships"]["stop"]["data"]["id"]
        end)

        {:noreply, schedules}
    end
  end

  def handle_call({:get_headways, stop_id, current_time}, _from, state) do
    schedules = state[stop_id]
    {:reply, Map.get(ScheduleHeadway.group_headways_for_stations(schedules, [stop_id], current_time), stop_id), state}
  end

  def handle_call({:register, gtfs_stop_id}, _from, state) do
    state = Map.put(state, gtfs_stop_id, [])
    schedule_update(self())
    {:reply, state, state}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update_headways, 10_000)
  end
end
