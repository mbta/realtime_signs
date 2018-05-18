defmodule Engine.Config do
  @moduledoc """
  Manages the dynamic configurable pieces of the signs such as if they are on
  """

  use GenServer
  require Logger

  @type version_id :: String.t | nil

  @table __MODULE__

  def start_link(name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @spec enabled?(String.t()) :: boolean
  def enabled?(sign_id) do
    case :ets.lookup(@table, sign_id) do
      [{^sign_id, %{"enabled" => false}}] -> false
      _ -> true
    end
  end

  def update(pid \\ __MODULE__) do
    schedule_update(pid, 0)
  end

  @spec handle_info(:update, version_id) :: {:noreply, %{}}
  def handle_info(:update, current_version) do
    schedule_update(self())
    updater = Application.get_env(:realtime_signs, :external_config_getter)
    latest_version = case updater.get(current_version) do
      {version, config} ->
        config = config
        |> Enum.into([])
        :ets.insert(@table, config)
        version
      :unchanged ->
        current_version
    end

    {:noreply, latest_version}
  end

  @spec init(any()) :: {:ok, version_id}
  def init(_) do
    schedule_update(self())
    @table = :ets.new(@table, [:set, :protected, :named_table, read_concurrency: true])
    {:ok, nil}
  end

  defp schedule_update(pid, time \\ 1_000) do
    Process.send_after(pid, :update, time)
  end
end
