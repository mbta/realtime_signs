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

      Process.sleep(500)
      assert Process.alive?(pid)

      log =
        capture_log(fn ->
          send(pid, :unknown_message)
        end)

      assert Process.alive?(pid)
      assert log =~ "unhandled message"
    end
  end

  describe "stop_status returns ETS data inserted by periodic :fetch" do
    defmodule FakeAlertsFetcherHappy do
      @behaviour Engine.Alerts.Fetcher

      @impl true
      def get_statuses do
        {:ok,
         %{
           :stop_statuses => %{
             "123" => :shuttles_closed_station,
             "234" => :shuttles_transfer_station
           },
           :route_statuses => %{
             "Red" => :suspension
           }
         }}
      end
    end

    defmodule FakeAlertsFetcherSad do
      @behaviour Engine.Alerts.Fetcher

      @impl true
      def get_statuses do
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

      state = %{
        stops_ets_table_name: stops_ets_table_name,
        routes_ets_table_name: routes_ets_table_name,
        fetcher: FakeAlertsFetcherHappy,
        fetch_ms: 30_000
      }

      {:noreply, _state} = Engine.Alerts.handle_info(:fetch, state)

      assert Engine.Alerts.stop_status(stops_ets_table_name, "123") == :shuttles_closed_station

      assert Engine.Alerts.stop_status(stops_ets_table_name, "234") == :shuttles_transfer_station
      assert Engine.Alerts.stop_status(stops_ets_table_name, "n/a") == :none

      assert Engine.Alerts.max_stop_status(stops_ets_table_name, ["n/a-1", "n/a-2"]) == :none

      assert Engine.Alerts.max_stop_status(stops_ets_table_name, ["n/a", "123"]) ==
               :shuttles_closed_station

      assert Engine.Alerts.max_stop_status(stops_ets_table_name, ["n/a", "123", "234"]) ==
               :shuttles_closed_station

      assert Engine.Alerts.max_stop_status(stops_ets_table_name, ["n/a", "234"]) ==
               :shuttles_transfer_station

      assert Engine.Alerts.route_status(routes_ets_table_name, "Red") == :suspension
      assert Engine.Alerts.route_status(routes_ets_table_name, "Orange") == :none
    end

    test "when alerts fetch fails, keeps old state" do
      stops_ets_table_name = :engine_alerts_test_sad_path_stops
      routes_ets_table_name = :engine_alerts_test_sad_path_routes

      ^stops_ets_table_name =
        :ets.new(stops_ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

      ^routes_ets_table_name =
        :ets.new(routes_ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

      :ets.insert(stops_ets_table_name, [{"abc", :shuttles_closed_station}])

      state = %{
        stops_ets_table_name: stops_ets_table_name,
        routes_ets_table_name: routes_ets_table_name,
        fetcher: FakeAlertsFetcherSad,
        fetch_ms: 30_000
      }

      log =
        capture_log(fn ->
          {:noreply, _state} = Engine.Alerts.handle_info(:fetch, state)
        end)

      assert log =~ "could not fetch"
      assert Engine.Alerts.stop_status(stops_ets_table_name, "abc") == :shuttles_closed_station
    end
  end
end
