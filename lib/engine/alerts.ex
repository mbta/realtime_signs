defmodule Engine.Alerts do
  use GenServer
  require Logger
  alias Engine.Alerts.Fetcher

  @type state :: %{
          ets_table_name: term(),
          fetcher: module(),
          fetch_ms: integer()
        }

  def start_link(opts \\ []) do
    name = opts[:gen_server_name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec stop_status(Fetcher.stop_id()) :: Fetcher.stop_status()
  def stop_status(ets_table_name \\ __MODULE__, stop_id) do
    case :ets.lookup(ets_table_name, stop_id) do
      [{^stop_id, status}] -> status
      _ -> nil
    end
  end

  @spec init(Keyword.t()) :: {:ok, state()}
  def init(opts) do
    fetch_ms = opts[:fetch_ms] || 30_000
    fetcher = opts[:fetcher] || Engine.Alerts.ApiFetcher
    ets_table_name = opts[:ets_table_name] || __MODULE__

    schedule_fetch(self(), fetch_ms)

    ^ets_table_name =
      :ets.new(ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

    state = %{
      ets_table_name: ets_table_name,
      fetcher: fetcher,
      fetch_ms: fetch_ms
    }

    {:ok, state}
  end

  def handle_info(:fetch, state) do
    schedule_fetch(self(), state.fetch_ms)

    case state.fetcher.get_stop_statuses() do
      {:ok, statuses} ->
        :ets.delete_all_objects(state.ets_table_name)
        :ets.insert(state.ets_table_name, Enum.into(statuses, []))
        Logger.info("Engine.Alerts alert_statuses: #{inspect(statuses)}")

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
