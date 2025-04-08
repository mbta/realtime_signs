defmodule Engine.AlertsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  describe "GenServer initialization" do
    test "GenServer starts up successfully" do
      {:ok, pid} =
        Engine.Alerts.start_link(
          gen_server_name: __MODULE__,
          stops_ets_table_name: :stops_ets_table_test,
          routes_ets_table_name: :routes_ets_table_test
        )

      Process.sleep(50)
      assert Process.alive?(pid)

      log =
        capture_log(fn ->
          send(pid, :unknown_message)
          Process.sleep(50)
        end)

      assert Process.alive?(pid)
      assert log =~ "unhandled message"
    end
  end

  describe "stop_status returns ETS data inserted by periodic :fetch" do
    defmodule FakeAlertsFetcherHappy do
      @behaviour Engine.Alerts.Fetcher

      @impl true
      def get_statuses(_) do
        {:ok,
         %{
           :stop_statuses => %{
             "123" => :shuttles_closed_station,
             "234" => :shuttles_transfer_station
           },
           :route_statuses => %{
             "Red" => :suspension_closed_station,
             "Green-B" => :suspension_closed_station
           }
         }}
      end
    end

    defmodule FakeAlertsFetcherSad do
      @behaviour Engine.Alerts.Fetcher

      @impl true
      def get_statuses(_) do
        {:error, :didnt_work}
      end
    end

    test "works as described on the happy path" do
      stops_ets_table_name = :engine_alerts_test_happy_path_stops
      routes_ets_table_name = :engine_alerts_test_happy_path_routes

      ^stops_ets_table_name =
        :ets.new(stops_ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

      ^routes_ets_table_name =
        :ets.new(routes_ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

      tables = %{
        stops_table: stops_ets_table_name,
        routes_table: routes_ets_table_name
      }

      state = %{
        tables: tables,
        fetcher: FakeAlertsFetcherHappy,
        fetch_ms: 30_000,
        all_route_ids: []
      }

      {:noreply, _state} = Engine.Alerts.handle_info(:fetch, state)

      assert Engine.Alerts.stop_status(stops_ets_table_name, "123") == :shuttles_closed_station

      assert Engine.Alerts.stop_status(stops_ets_table_name, "234") == :shuttles_transfer_station
      assert Engine.Alerts.stop_status(stops_ets_table_name, "n/a") == :none

      assert Engine.Alerts.min_stop_status(tables, ["n/a-1", "n/a-2"]) == :none

      assert Engine.Alerts.min_stop_status(tables, ["n/a-1", "123"]) ==
               :none

      assert Engine.Alerts.min_stop_status(tables, ["123", "234"]) ==
               :shuttles_transfer_station

      assert Engine.Alerts.route_status(routes_ets_table_name, "Red") ==
               :suspension_closed_station

      assert Engine.Alerts.route_status(routes_ets_table_name, "Orange") == :none
    end

    test "when alerts fetch fails, keeps the state" do
      stops_ets_table_name = :engine_alerts_test_sad_path_stops
      routes_ets_table_name = :engine_alerts_test_sad_path_routes

      ^stops_ets_table_name =
        :ets.new(stops_ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

      ^routes_ets_table_name =
        :ets.new(routes_ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

      :ets.insert(stops_ets_table_name, [{"abc", :shuttles_closed_station}])
      :ets.insert(routes_ets_table_name, [{"Red", :suspension}])

      tables = %{
        stops_table: stops_ets_table_name,
        routes_table: routes_ets_table_name
      }

      state = %{
        tables: tables,
        fetcher: FakeAlertsFetcherSad,
        fetch_ms: 30_000,
        all_route_ids: []
      }

      log =
        capture_log(fn ->
          {:noreply, _state} = Engine.Alerts.handle_info(:fetch, state)
        end)

      assert log =~ "could not fetch"
      assert Engine.Alerts.stop_status(stops_ets_table_name, "abc") == :shuttles_closed_station
      assert Engine.Alerts.route_status(routes_ets_table_name, "Red") == :suspension
    end
  end
end
