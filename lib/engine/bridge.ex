defmodule Engine.Bridge do
  @moduledoc """
  Maintains the status of all bridgees we care about
  """

  use GenServer
  require Logger

  @type bridge_id :: String.t()
  @type status :: String.t() | nil
  @type duration :: integer | nil

  @type state :: %{
          ets_table_name: term()
        }

  @fetch_ms 60 * 1_000

  def start_link(name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @spec status(term(), bridge_id) :: {status, duration} | nil
  def status(ets_table_name \\ __MODULE__, id) do
    case :ets.lookup(ets_table_name, id) do
      [{^id, status}] -> status
      _ -> nil
    end
  end

  @spec update(GenServer.server()) :: any()
  def update(pid \\ __MODULE__) do
    Kernel.send(pid, :update)
  end

  @spec init(Keyword.t()) :: {:ok, any()}
  def init(opts) do
    ets_table_name = opts[:ets_table_name] || __MODULE__

    ^ets_table_name =
      :ets.new(ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

    schedule_update(self())

    state = %{ets_table_name: ets_table_name}

    {:ok, state}
  end

  def handle_info(:update, state) do
    schedule_update(self())
    bridge_request = Application.get_env(:realtime_signs, :bridge_requester)
    bridge_status = bridge_request.get_status("1", Timex.now())

    :ets.insert(state.ets_table_name, [{"1", bridge_status}])

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warn("#{__MODULE__} unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, @fetch_ms)
  end
end
