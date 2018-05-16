defmodule Engine.Config do
  @moduledoc """
  Manages the dynamic configurable pieces of the signs such as if they are on
  """

  use GenServer
  require Logger

  def start_link(name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def enabled?(sign_id) do
    case :ets.lookup(:config, sign_id) do
      [{^sign_id, %{"enabled" => false}}] -> false
      _ -> true
    end
  end

  def update(pid \\ __MODULE__) do
    schedule_update(pid, 0)
  end

  def handle_info(:update, _state) do
    schedule_update(self())
    updater = Application.get_env(:realtime_signs, :external_config_getter)
    config = updater.get()
    Enum.each(config, fn {key, val} ->
      :ets.insert(:config, {key, val})
    end)
    {:noreply, %{}}
  end

  @spec init(any()) :: {:ok, any()}
  def init(_) do
    schedule_update(self())
    :ets.new(:config, [:set, :public, :named_table])
    {:ok, %{}}
  end

  defp schedule_update(pid, time \\ 1_000) do
    Process.send_after(pid, :update, time)
  end
end
