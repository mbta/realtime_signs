defmodule Engine.Alerts do
  use GenServer
  require Logger
  alias Engine.Alerts.Fetcher

  @ets_table :engine_alerts

  @type state :: %{
    fetcher: module(),
    fetch_ms: integer(),
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec stop_status(Fetcher.stop_id()) :: Fetcher.stop_status()
  def stop_status(stop_id) do
    case :ets.lookup(@ets_table, stop_id) do
      [{^stop_id, status}] -> status
      _ -> nil
    end
  end

  @spec init(Keyword.t()) :: {:ok, state()}
  def init(opts) do
    fetch_ms = opts[:fetch_ms] || 30_000
    fetcher = opts[:fetcher] || Engine.Alerts.ApiFetcher

    schedule_fetch(self(), fetch_ms)

    @ets_table =
      :ets.new(@ets_table, [:set, :protected, :named_table, read_concurrency: true])

    state = %{
      fetcher: fetcher,
      fetch_ms: fetch_ms,
    }

    {:ok, state}
  end

  def handle_info(:fetch, state) do
    schedule_fetch(self(), state.fetch_ms)

    case state.fetcher.get_stop_statuses() do
      {:ok, statuses} ->
        :ets.delete_all_objects(@ets_table)
        :ets.insert(@ets_table, Enum.into(statuses, []))

      {:error, e} ->
        Logger.warn("Engine.Alerts could not fetch stop statuses: #{inspect(e)}")
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.error("Engine.Alerts unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp schedule_fetch(pid, ms) do
    Process.send_after(pid, :fetch, ms)
  end
end
