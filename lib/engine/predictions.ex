defmodule Engine.Predictions do
  use GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "The seconds away we predict vehicles are from the given stop"
  def for_stop(pid \\ __MODULE__, gtfs_stop_id) do
    GenServer.call(pid, {:for_stop, gtfs_stop_id})
  end

  def init([]) do
    schedule_update(self())
    Process.send_after(self(), :test_update, 5_000)
    state = %{"70265" => [80, 200], "70266" => [90, 180]}
    {:ok, state}
  end

  def handle_call({:for_stop, gtfs_stop_id}, _from, state) do
    {:reply, state[gtfs_stop_id], state}
  end

  def handle_info(:update, state) do
    schedule_update(self())
    Logger.info("Updating Predictions State...")
    {:noreply, state}
  end

  def handle_info(:test_update, state) do
    Logger.info("Test updating predictions state...")
    {:noreply, %{state | "70265" => [50, 150]}}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end
end
