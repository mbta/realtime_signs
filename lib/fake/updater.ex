defmodule Fake.Sign.Updater do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init(args) do
    {:ok, args}
  end

  def request(pid \\ __MODULE__, payload, current_time) do
    GenServer.cast(pid, {:request, payload, current_time})
  end

  def reset(pid \\ __MODULE__) do
    GenServer.call(pid, :reset)
  end

  def all_calls(pid \\ __MODULE__) do
    GenServer.call(pid, :all_calls)
  end

  def handle_cast({:request, payload, _current_time}, calls) do
    {:noreply, [payload | calls]}
  end

  def handle_call(:reset, _from, _calls) do
    {:reply, :ok, []}
  end
  def handle_call(:all_calls, _from, calls) do
    {:reply, Enum.reverse(calls), calls}
  end
end
