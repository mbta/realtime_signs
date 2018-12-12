defmodule Engine.HeadwaysTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  describe "GenServer initialization" do
    test "GenServer starts up successfully" do
      {:ok, pid} =
        Engine.Headways.start_link(gen_server_name: __MODULE__, ets_table_name: __MODULE__)

      Process.sleep(500)
      assert Process.alive?(pid)

      log =
        capture_log([level: :warn], fn ->
          send(pid, :unknown_message)
        end)

      assert Process.alive?(pid)
      assert log =~ "unknown message"
    end
  end

  describe "get_headways callback" do
    @times [
      ~N[2017-07-04 09:05:00],
      ~N[2017-07-04 08:55:00],
      ~N[2017-07-04 08:45:00],
      ~N[2017-07-04 09:20:00]
    ]

    test "returns a tuple of the min and max headway" do
      current_time = Timex.to_datetime(~N[2017-07-04 09:00:00], "America/New_York")

      schedules =
        Enum.map(@times, fn time ->
          %{
            "relationships" => %{"stop" => %{"data" => %{"id" => "123"}}},
            "attributes" => %{
              "departure_time" =>
                Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
            }
          }
        end)

      state = %{"123" => schedules}

      assert Engine.Headways.handle_call({:get_headways, "123"}, self(), state) ==
               {:reply, {10, 17}, state}
    end
  end

  describe "data_update callback" do
    test "updates all gtfs stop id schedule data in the state" do
      schedules =
        Enum.map(@times, fn time ->
          %{
            "relationships" => %{"stop" => %{"data" => %{"id" => "123"}}},
            "attributes" => %{
              "departure_time" =>
                Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")
            }
          }
        end)

      state = %{"123" => schedules}
      {:noreply, updated_state} = Engine.Headways.handle_info(:data_update, state)

      for {state_schedule, index} <- updated_state |> Map.get("123") |> Enum.with_index() do
        schedule = Enum.at(schedules, index)

        assert get_in(schedule, ["attributes", "departure_time"]) ==
                 get_in(state_schedule, ["attributes", "departure_time"])

        id_path = ["relationships", "stop", "data", "id"]
        assert get_in(schedule, id_path) == get_in(state_schedule, id_path)
      end
    end
  end

  describe "get_headways/2" do
    test "defers to the headway calculator" do
      log =
        capture_log([level: :info], fn ->
          Engine.Headways.get_headways("123")
        end)

      assert log =~ "group_headways_for_stations called"
    end
  end
end
