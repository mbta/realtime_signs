defmodule Engine.Alerts do
  use GenServer
  require Logger
  alias Engine.Alerts.Fetcher
  alias Signs.Utilities.EtsUtils

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

  # Platfrom stop IDs that don't receive Alerts
  @platform_stop_ids MapSet.new([
                       "Alewife-01",
                       "Alewife-02",
                       "Braintree-01",
                       "Braintree-02",
                       "Forest Hills-01",
                       "Forest Hills-02",
                       "Oak Grove-01",
                       "Oak Grove-02",
                       "Government Center-Brattle",
                       "71199",
                       "Union Square-01",
                       "Union Square-02"
                     ])

  def start_link(opts \\ []) do
    name = opts[:gen_server_name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @callback min_stop_status([Fetcher.stop_id()]) :: Fetcher.stop_status()
  def min_stop_status(
        tables \\ %{stops_table: @stops_table, routes_table: @routes_table},
        stop_ids
      ) do
    stop_ids
    |> Enum.reject(&MapSet.member?(@platform_stop_ids, &1))
    |> Enum.map(&stop_status(tables.stops_table, &1))
    |> Enum.min_by(&Fetcher.get_priority_level/1)
  end

  @callback stop_status(Fetcher.stop_id()) :: Fetcher.stop_status()
  def stop_status(ets_table_name \\ @stops_table, stop_id) do
    case :ets.lookup(ets_table_name, stop_id) do
      [{^stop_id, status}] -> status
      _ -> :none
    end
  end

  @callback route_status(Fetcher.route_id()) :: Fetcher.stop_status()
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
        EtsUtils.write_ets(state.tables.routes_table, route_statuses, :none)
        EtsUtils.write_ets(state.tables.stops_table, stop_statuses, :none)

        Logger.info(
          "Engine.Alerts Stop alert statuses: #{inspect(stop_statuses)} Route alert statuses #{inspect(route_statuses)}"
        )

      {:error, e} ->
        Logger.warning("Engine.Alerts could not fetch stop statuses: #{inspect(e)}")
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
