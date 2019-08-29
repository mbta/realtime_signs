defmodule Engine.ScheduledHeadwaysTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  describe "GenServer initialization" do
    test "GenServer starts up successfully" do
      {:ok, pid} =
        Engine.ScheduledHeadways.start_link(
          gen_server_name: __MODULE__,
          ets_table_name: __MODULE__,
          time_fetcher: fn -> Timex.to_datetime(~N[2017-07-04 09:00:00], "America/New_York") end
        )

      Process.sleep(500)
      assert Process.alive?(pid)

      log =
        capture_log([level: :warn], fn ->
          send(pid, :unknown_message)
          Process.sleep(500)
        end)

      assert Process.alive?(pid)
      assert log =~ "unknown message"
    end
  end

  defmodule FakeScheduleFetcher do
    @times [
      ~N[2017-07-04 09:05:00],
      ~N[2017-07-04 08:55:00],
      ~N[2017-07-04 08:45:00],
      ~N[2017-07-04 09:20:00]
    ]

    def get_schedules(_station_ids) do
      Enum.map(@times, fn time ->
        %{
          "relationships" => %{"stop" => %{"data" => %{"id" => "123"}}},
          "attributes" => %{
            "departure_time" =>
              Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
          }
        }
      end)
    end

    def get_test_times() do
      @times
    end
  end

  describe "get_headways callback" do
    test "returns a tuple of the min and max headway" do
      ets_table_name = :engine_headways_test_get_headways

      ^ets_table_name =
        :ets.new(ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

      state = %{
        ets_table_name: ets_table_name,
        schedule_data: %{},
        fetcher: FakeScheduleFetcher,
        fetch_ms: 30_000,
        headway_calc_ms: 30_000,
        stop_ids: ["123"],
        time_fetcher: fn -> Timex.to_datetime(~N[2017-07-04 09:00:00], "America/New_York") end
      }

      {:noreply, state} = Engine.ScheduledHeadways.handle_info(:data_update, state)
      {:noreply, state} = Engine.ScheduledHeadways.handle_info(:calculation_update, state)

      assert Engine.ScheduledHeadways.get_headways(state.ets_table_name, "123") == {10, 17}
    end
  end

  describe "data_update callback" do
    test "updates all gtfs stop id schedule data in the state" do
      schedules =
        Enum.map(FakeScheduleFetcher.get_test_times(), fn time ->
          %{
            "relationships" => %{"stop" => %{"data" => %{"id" => "123"}}},
            "attributes" => %{
              "departure_time" =>
                Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
            }
          }
        end)

      state = %{
        schedule_data: %{"123" => schedules},
        fetcher: FakeScheduleFetcher,
        fetch_ms: 30_000,
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
  end
end
