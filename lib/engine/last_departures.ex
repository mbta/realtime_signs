defmodule Engine.LastDepartures do
  @moduledoc """
  Tracks how long ago a train departed from any given stop for use with Headways
  """
  use GenServer
  require Logger
  require Signs.Utilities.SignsConfig

  @type t :: %{
          String.t() => DateTime.t()
        }

  def start_link(opts \\ []) do
    gen_server_name = opts[:gen_server_name] || __MODULE__
    engine_opts = Keyword.delete(opts, :gen_server_name)
    GenServer.start_link(__MODULE__, engine_opts, name: gen_server_name)
  end

  def init(_opts) do
    {:ok, %{}}
  end

  def add_departure(pid \\ __MODULE__, stop_id, time) do
    GenServer.call(pid, {:add_departure, stop_id, time})
  end

  def get_last_departure(pid \\ __MODULE__, stop_id) do
    GenServer.call(pid, {:get_last_departure, stop_id})
  end

  def handle_call({:add_departure, stop_id, time}, _from, state) do
    new_state = Map.put(state, stop_id, time)
    {:reply, new_state, new_state}
  end

  def handle_call({:get_last_departure, stop_id}, _from, state) do
    {:reply, state[stop_id], state}
  end
end
