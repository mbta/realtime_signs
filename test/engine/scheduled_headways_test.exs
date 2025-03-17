defmodule Engine.ScheduledHeadwaysTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  @ets_table_params [:set, :protected, :named_table, read_concurrency: true]

  describe "GenServer initialization" do
    test "GenServer starts up successfully" do
      {:ok, pid} =
        Engine.ScheduledHeadways.start_link(
          gen_server_name: __MODULE__,
          headways_ets_table: :genserver_test_headways,
          first_last_departures_ets_table: :genserver_test_first_last_departures,
          time_fetcher: fn -> Timex.to_datetime(~N[2017-07-04 09:00:00], "America/New_York") end
        )

      Process.sleep(500)
      assert Process.alive?(pid)

      log =
        capture_log([level: :warning], fn ->
          send(pid, :unknown_message)
          Process.sleep(50)
        end)

      assert Process.alive?(pid)
      assert log =~ "unknown message"
    end
  end

  defmodule FakeScheduleFetcher do
    @times [
      "2017-07-04T09:05:00-04:00",
      "2017-07-04T08:55:00-04:00",
      "2017-07-04T08:45:00-04:00",
      "2017-07-04T09:20:00-04:00"
    ]

    def get_schedules(["123"]) do
      get_test_times("123")
    end

    def get_schedules(["456"]) do
      []
    end

    def get_schedules(["789"]) do
      :error
    end

    def get_schedules(["first_last_departures"]) do
      [
        %{
          "relationships" => %{"stop" => %{"data" => %{"id" => "first_last_departures"}}},
          "attributes" => %{
            "arrival_time" =>
              Timex.format!(
                Timex.to_datetime(~N[2017-07-04 08:35:00], "America/New_York"),
                "{ISO:Extended}"
              )
          }
        }
        | get_test_times("first_last_departures")
      ]
    end

    def get_test_times(stop_id) do
      Enum.map(@times, fn time ->
        %{
          "relationships" => %{"stop" => %{"data" => %{"id" => stop_id}}},
          "attributes" => %{
            "departure_time" => time
          }
        }
      end)
    end
  end

  describe "get_first_last_departures/2" do
    test "returns a tuple of the first and last departure" do
      headways_ets_table = :engine_headways_test_get_headways
      first_last_departures_ets_table = :engine_first_last_departures_test_get_headways

      ^headways_ets_table = :ets.new(headways_ets_table, @ets_table_params)

      ^first_last_departures_ets_table =
        :ets.new(first_last_departures_ets_table, [
          :set,
          :protected,
          :named_table,
          read_concurrency: true
        ])

      state = %{
        headways_ets_table: headways_ets_table,
        first_last_departures_ets_table: first_last_departures_ets_table,
        schedule_data: %{},
        fetcher: FakeScheduleFetcher,
        fetch_ms: 30_000,
        fetch_chunk_size: 20,
        headway_calc_ms: 30_000,
        stop_ids: ["first_last_departures"],
        time_fetcher: fn -> Timex.to_datetime(~N[2017-07-04 09:00:00], "America/New_York") end
      }

      {:noreply, state} = Engine.ScheduledHeadways.handle_info(:data_update, state)

      [{first_departure, last_departure}] =
        Engine.ScheduledHeadways.get_first_last_departures(
          state.first_last_departures_ets_table,
          ["first_last_departures"]
        )

      assert DateTime.to_naive(first_departure) == ~N[2017-07-04 08:35:00]
      assert DateTime.to_naive(last_departure) == ~N[2017-07-04 09:20:00]
    end

    test "returns a tuple of nil, nil when no information found" do
      headways_ets_table = :engine_headways_test_get_headways_nil_case
      first_last_departures_ets_table = :engine_first_last_departures_test_get_headways_nil_case

      ^headways_ets_table = :ets.new(headways_ets_table, @ets_table_params)

      ^first_last_departures_ets_table =
        :ets.new(first_last_departures_ets_table, [
          :set,
          :protected,
          :named_table,
          read_concurrency: true
        ])

      state = %{
        headways_ets_table: headways_ets_table,
        first_last_departures_ets_table: first_last_departures_ets_table,
        schedule_data: %{},
        fetcher: FakeScheduleFetcher,
        fetch_ms: 30_000,
        fetch_chunk_size: 20,
        headway_calc_ms: 30_000,
        stop_ids: ["first_last_departures"],
        time_fetcher: fn -> Timex.to_datetime(~N[2017-07-04 09:00:00], "America/New_York") end
      }

      {:noreply, state} = Engine.ScheduledHeadways.handle_info(:data_update, state)

      assert Engine.ScheduledHeadways.get_first_last_departures(
               state.first_last_departures_ets_table,
               ["unknown_stop_id"]
             ) == []
    end
  end

  describe "display_headways?/4" do
    test "returns true/false depending on time" do
      table = :display_headways_test
      stop = "stop"
      headways = %Engine.Config.Headway{headway_id: {"test", :peak}, range_high: 12, range_low: 5}

      first_departure = DateTime.from_naive!(~N[2020-03-24 10:00:00], "America/New_York")
      last_departure = DateTime.from_naive!(~N[2020-03-25 01:00:00], "America/New_York")

      :ets.new(table, @ets_table_params)
      :ets.insert(table, {stop, {first_departure, last_departure}})

      before_service = DateTime.add(first_departure, -1 * (headways.range_high + 5) * 60)
      during_buffer = DateTime.add(first_departure, -1 * (headways.range_high - 5) * 60)
      during_service = DateTime.add(first_departure, 3 * 60 * 60)
      after_service = DateTime.add(last_departure, 5 * 60)

      refute Engine.ScheduledHeadways.display_headways?(
               table,
               [stop],
               before_service,
               headways
             )

      assert Engine.ScheduledHeadways.display_headways?(table, [stop], during_buffer, headways)

      assert Engine.ScheduledHeadways.display_headways?(
               table,
               [stop],
               during_service,
               headways
             )

      refute Engine.ScheduledHeadways.display_headways?(table, [stop], after_service, headways)
    end

    test "uses the earliest first and earliest last departure" do
      table = :dh_multiple_test

      early_first_dep = DateTime.from_naive!(~N[2020-03-20 05:00:00], "America/New_York")
      later_first_dep = DateTime.from_naive!(~N[2020-03-20 06:00:00], "America/New_York")
      in_service_early = DateTime.from_naive!(~N[2020-03-20 05:15:00], "America/New_York")

      early_last_dep = DateTime.from_naive!(~N[2020-03-21 00:00:00], "America/New_York")
      later_last_dep = DateTime.from_naive!(~N[2020-03-21 02:00:00], "America/New_York")
      no_service_late = DateTime.from_naive!(~N[2020-03-21 01:00:00], "America/New_York")
      headways = %Engine.Config.Headway{headway_id: {"test", :peak}, range_high: 0, range_low: 0}

      :ets.new(table, @ets_table_params)
      :ets.insert(table, {"stop1", {early_first_dep, later_last_dep}})
      :ets.insert(table, {"stop2", {later_first_dep, early_last_dep}})

      assert Engine.ScheduledHeadways.display_headways?(
               table,
               ["stop1", "stop2"],
               in_service_early,
               headways
             )

      refute Engine.ScheduledHeadways.display_headways?(
               table,
               ["stop1", "stop2"],
               no_service_late,
               headways
             )
    end

    test "handles when the only departure times are nil" do
      table = :dh_nil_test
      datetime = DateTime.from_naive!(~N[2020-03-20 12:00:00], "America/New_York")
      headways = %Engine.Config.Headway{headway_id: {"test", :peak}, range_high: 0, range_low: 0}

      :ets.new(table, @ets_table_params)
      :ets.insert(table, {"stop_id", {nil, nil}})
      :ets.insert(table, {"stop_id", {nil, nil}})

      refute Engine.ScheduledHeadways.display_headways?(table, ["stop_id"], datetime, headways)
    end

    test "returns false if missing first/last trip timing" do
      :ets.new(:no_data, @ets_table_params)
      time = DateTime.from_naive!(~N[2020-03-20 10:00:00], "America/New_York")
      headways = %Engine.Config.Headway{headway_id: {"test", :peak}, range_high: 0, range_low: 0}
      refute Engine.ScheduledHeadways.display_headways?(:no_data, ["no_stop"], time, headways)
    end
  end

  describe "data_update callback" do
    test "updates all gtfs stop id schedule data in the state" do
      schedules = FakeScheduleFetcher.get_test_times("123")

      :first_last_departures_test1 =
        :ets.new(:first_last_departures_test1, [
          :set,
          :protected,
          :named_table,
          read_concurrency: true
        ])

      state = %{
        schedule_data: %{"123" => schedules},
        first_last_departures_ets_table: :first_last_departures_test1,
        fetcher: FakeScheduleFetcher,
        fetch_ms: 30_000,
        fetch_chunk_size: 20,
        stop_ids: ["123"]
      }

      {:noreply, updated_state} = Engine.ScheduledHeadways.handle_info(:data_update, state)
      updated_schedule = updated_state.schedule_data

      for {state_schedule, index} <- Enum.with_index(updated_schedule["123"]) do
        schedule = Enum.at(schedules, index)

        assert get_in(schedule, ["attributes", "departure_time"]) ==
                 get_in(state_schedule, ["attributes", "departure_time"])

        id_path = ["relationships", "stop", "data", "id"]
        assert get_in(schedule, id_path) == get_in(state_schedule, id_path)
      end
    end

    test "handles empty results from request" do
      schedules_123 = FakeScheduleFetcher.get_test_times("123")
      schedules_456 = FakeScheduleFetcher.get_test_times("456")

      :first_last_departures_test2 =
        :ets.new(:first_last_departures_test2, [
          :set,
          :protected,
          :named_table,
          read_concurrency: true
        ])

      state = %{
        schedule_data: %{"123" => schedules_123, "456" => schedules_456},
        first_last_departures_ets_table: :first_last_departures_test2,
        fetcher: FakeScheduleFetcher,
        fetch_ms: 30_000,
        fetch_chunk_size: 1,
        stop_ids: ["123", "456"]
      }

      {:noreply, updated_state} = Engine.ScheduledHeadways.handle_info(:data_update, state)
      assert updated_state.schedule_data == %{"123" => schedules_123, "456" => []}
    end

    test "handles errors in the request" do
      schedules_123 = FakeScheduleFetcher.get_test_times("123")
      schedules_789 = FakeScheduleFetcher.get_test_times("789")

      :first_last_departures_test3 =
        :ets.new(:first_last_departures_test3, [
          :set,
          :protected,
          :named_table,
          read_concurrency: true
        ])

      state = %{
        schedule_data: %{"123" => schedules_123, "789" => schedules_789},
        first_last_departures_ets_table: :first_last_departures_test3,
        fetcher: FakeScheduleFetcher,
        fetch_ms: 30_000,
        fetch_chunk_size: 1,
        stop_ids: ["123", "789"]
      }

      {:noreply, updated_state} = Engine.ScheduledHeadways.handle_info(:data_update, state)

      assert state.schedule_data == updated_state.schedule_data
    end

    test "returns DateTimes in a valid format" do
      schedules_123 = FakeScheduleFetcher.get_test_times("123")

      :first_last_departures_test4 =
        :ets.new(:first_last_departures_test4, [
          :set,
          :protected,
          :named_table,
          read_concurrency: true
        ])

      state = %{
        schedule_data: %{"123" => schedules_123},
        first_last_departures_ets_table: :first_last_departures_test4,
        fetcher: FakeScheduleFetcher,
        fetch_ms: 30_000,
        fetch_chunk_size: 1,
        stop_ids: ["123"]
      }

      {:noreply, _updated_state} = Engine.ScheduledHeadways.handle_info(:data_update, state)

      [{first, _}] =
        Engine.ScheduledHeadways.get_first_last_departures(:first_last_departures_test4, ["123"])

      # Ensure that after parsing and loading datetimes we can use them with native functions.
      # Timex had a bug where its parser would result in an invalid datetime which blows up
      # non-Timex datetime operations.
      assert DateTime.add(first, 10)
    end
  end
end
