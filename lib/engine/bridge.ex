defmodule Engine.Bridge do
  @moduledoc """
  Maintains the status of all bridgees we care about
  """

  use GenServer
  require Logger

  @type bridge_id :: String.t()
  @type status :: String.t() | nil
  @type duration :: integer | nil

  @type t :: %{bridge_id => {status, duration}}

  def start_link(name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @spec status(GenServer.server(), bridge_id) :: {status, duration}
  def status(pid \\ __MODULE__, id) do
    GenServer.call(pid, {:status, id})
  end

  @spec update(GenServer.server()) :: t
  def update(pid \\ __MODULE__) do
    Kernel.send(pid, :update)
  end

  @spec init(any()) :: {:ok, any()}
  def init(_) do
    schedule_update(self())
    {:ok, %{}}
  end

  def handle_info(:update, _state) do
    schedule_update(self())
    bridge_request = Application.get_env(:realtime_signs, :bridge_requester)
    bridge_status = bridge_request.get_status("1")

    {:noreply, %{"1" => bridge_status}}
  end

  def handle_call({:status, id}, _from, state) do
    {:reply, state[id], state}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 60 * 1_000)
  end
end
