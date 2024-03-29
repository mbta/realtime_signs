defmodule Engine.Alerts do
  @behaviour Engine.AlertsAPI
  use GenServer
  require Logger
  alias Engine.Alerts.Fetcher

  @type ets_tables :: %{
          stops_table: :ets.tab(),
          routes_table: :ets.tab()
        }

  @type state :: %{
          tables: ets_tables(),
          fetcher: module(),
          fetch_ms: integer(),
          all_route_ids: [String.t()]
        }

  @stops_table :alerts_by_stop
  @routes_table :alerts_by_route

  def start_link(opts \\ []) do
    name = opts[:gen_server_name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def max_stop_status(
        tables \\ %{stops_table: @stops_table, routes_table: @routes_table},
        stop_ids,
        route_ids
      ) do
    overall_stop_status =
      Enum.reduce(stop_ids, :none, fn stop_id, overall_status ->
        stop_status(tables.stops_table, stop_id)
        |> Fetcher.higher_priority_status(overall_status)
      end)

    route_states = Enum.map(route_ids, &route_status(tables.routes_table, &1))

    overall_route_status =
      Enum.reduce(route_states, :none, fn route_state, overall_status ->
        Fetcher.higher_priority_status(route_state, overall_status)
      end)

    if Enum.all?(route_states, fn s -> s == overall_route_status end) do
      Fetcher.higher_priority_status(overall_stop_status, overall_route_status)
    else
      overall_stop_status
    end
  end

  @spec stop_status(:ets.tab(), Fetcher.stop_id()) :: Fetcher.stop_status()
  def stop_status(ets_table_name \\ @stops_table, stop_id) do
    case :ets.lookup(ets_table_name, stop_id) do
      [{^stop_id, status}] -> status
      _ -> :none
    end
  end

  @spec route_status(:ets.tab(), Fetcher.route_id()) :: Fetcher.stop_status()
  def route_status(ets_table_name \\ @routes_table, route_id) do
    case :ets.lookup(ets_table_name, route_id) do
      [{^route_id, status}] -> status
      _ -> :none
    end
  end

  @impl true
  def init(opts) do
    fetch_ms = opts[:fetch_ms] || 30_000
    fetcher = opts[:fetcher] || Engine.Alerts.ApiFetcher

    stops_ets_table_name = opts[:stops_ets_table_name] || @stops_table
    routes_ets_table_name = opts[:routes_ets_table_name] || @routes_table

    schedule_fetch(self(), fetch_ms)

    ^stops_ets_table_name =
      :ets.new(stops_ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

    ^routes_ets_table_name =
      :ets.new(routes_ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

    state = %{
      tables: %{
        stops_table: stops_ets_table_name,
        routes_table: routes_ets_table_name
      },
      fetcher: fetcher,
      fetch_ms: fetch_ms,
      all_route_ids: Signs.Utilities.SignsConfig.all_route_ids()
    }

    {:ok, state}
  end

  @impl true
  def handle_info(:fetch, state) do
    schedule_fetch(self(), state.fetch_ms)

    case state.fetcher.get_statuses(state.all_route_ids) do
      {:ok, %{:stop_statuses => stop_statuses, :route_statuses => route_statuses}} ->
        :ets.delete_all_objects(state.tables.stops_table)
        :ets.insert(state.tables.stops_table, Enum.into(stop_statuses, []))
        :ets.delete_all_objects(state.tables.routes_table)
        :ets.insert(state.tables.routes_table, Enum.into(route_statuses, []))

        Logger.info(
          "Engine.Alerts Stop alert statuses: #{inspect(stop_statuses)} Route alert statuses #{inspect(route_statuses)}"
        )

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
