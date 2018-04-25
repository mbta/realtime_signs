defmodule Engine.Headways do
  use GenServer

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
        |> Enum.reduce(state, fn  schedule, acc ->
          id = schedule["relationships"]["stop"]["data"]["id"]
          Map.put(state, id, state[id] ++ [schedule])
        end)
        {:noreply, schedules}
    end
  end

  def handle_call({:register, gtfs_stop_id}, _from, state) do
    state = Map.put(state, gtfs_stop_id, [])
    {:reply, state, state}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update_headways, 10_000)
  end
end
