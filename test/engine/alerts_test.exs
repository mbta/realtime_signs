defmodule Engine.AlertsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  describe "GenServer initialization" do
    test "GenServer starts up successfully" do
      {:ok, pid} =
        Engine.Alerts.start_link(gen_server_name: __MODULE__, ets_table_name: __MODULE__)

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
      def get_stop_statuses do
        {:ok, %{"123" => :shuttles_closed_station, "234" => :shuttles_transfer_station}}
      end
    end

    defmodule FakeAlertsFetcherSad do
      def get_stop_statuses do
        {:error, :didnt_work}
      end
    end

    test "works as described on the happy path" do
      ets_table_name = :engine_alerts_test_happy_path

      ^ets_table_name =
        :ets.new(ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

      state = %{
        ets_table_name: ets_table_name,
        fetcher: FakeAlertsFetcherHappy,
        fetch_ms: 30_000
      }

      {:noreply, _state} = Engine.Alerts.handle_info(:fetch, state)
      assert Engine.Alerts.stop_status(ets_table_name, "123") == :shuttles_closed_station
      assert Engine.Alerts.stop_status(ets_table_name, "234") == :shuttles_transfer_station
      assert is_nil(Engine.Alerts.stop_status(ets_table_name, "n/a"))
    end

    test "when alerts fetch fails, keeps old state" do
      ets_table_name = :engine_alerts_test_sad_path

      ^ets_table_name =
        :ets.new(ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

      :ets.insert(ets_table_name, [{"abc", :shuttles_closed_station}])

      state = %{
        ets_table_name: ets_table_name,
        fetcher: FakeAlertsFetcherSad,
        fetch_ms: 30_000
      }

      log =
        capture_log(fn ->
          {:noreply, _state} = Engine.Alerts.handle_info(:fetch, state)
        end)

      assert log =~ "could not fetch"
      assert Engine.Alerts.stop_status(ets_table_name, "abc") == :shuttles_closed_station
    end
  end
end
