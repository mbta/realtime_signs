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
        replace_contents(state.tables.routes_table, route_statuses)
        replace_contents(state.tables.stops_table, stop_statuses)
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

  # Safely replaces table contents.
  #
  # ETS doesn't support atomic bulk writes, so we can't just clear the whole table
  # (:ets.delete_all_objects/1) and then insert all of the new entries (:ets.insert/2),
  # because that would leave the table completely empty for a short period,
  # causing any concurrent reads during that time to fail.
  #
  # Instead, we remove only the table entries that are absent from new_entries.
  defp replace_contents(table, new_entry) when is_tuple(new_entry) do
    replace_contents(table, [new_entry])
  end

  defp replace_contents(table, new_entries) do
    new_keys = MapSet.new(new_entries, &elem(&1, 0))
    current_table_keys = keys(table)

    removed_keys = MapSet.difference(current_table_keys, new_keys)
    Enum.each(removed_keys, &:ets.delete(table, &1))

    # Insert/update the new entries. (Analogous to Map.merge/2)
    :ets.insert(table, new_entries)
  end

  # Returns a MapSet of all keys in the table.
  defp keys(table) do
    keys(table, :ets.first(table), [])
  end

  defp keys(_table, :"$end_of_table", acc), do: MapSet.new(acc)

  defp keys(table, key, acc) do
    keys(table, :ets.next(table, key), [key | acc])
  end

end
