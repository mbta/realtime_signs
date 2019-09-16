defmodule Engine.DeparturesTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  defmodule FakeScheduledHeadwaysEngine do
    def get_first_last_departures(_) do
      {Timex.to_datetime(~N[2019-09-02 05:00:00], "America/New_York"),
       Timex.to_datetime(~N[2019-09-02 23:00:00], "America/New_York")}
    end

    def get_headways(_) do
      {5, 10}
    end
  end

  describe "update_train_state/3" do
    test "records the most recent departure at a stop id" do
      {:ok, departures_pid} = Engine.Departures.start_link(gen_server_name: :departures_test)
      stops1 = MapSet.new(["a", "b"])
      stops2 = MapSet.new(["a"])
      stops3 = MapSet.new(["b"])
      stops4 = MapSet.new([])

      time1 = Timex.now()

      :ok =
        Engine.Departures.update_train_state(
          departures_pid,
          stops1,
          time1
        )

      :ok =
        Engine.Departures.update_train_state(
          departures_pid,
          stops2,
          time1
        )

      assert :sys.get_state(departures_pid).departures == %{"b" => [time1]}

      time2 = Timex.shift(time1, minutes: 3)

      :ok =
        Engine.Departures.update_train_state(
          departures_pid,
          stops3,
          time2
        )

      assert :sys.get_state(departures_pid).departures == %{"a" => [time2], "b" => [time1]}

      time3 = Timex.shift(time2, minutes: 3)

      :ok =
        Engine.Departures.update_train_state(
          departures_pid,
          stops4,
          time3
        )

      assert :sys.get_state(departures_pid).departures == %{"a" => [time2], "b" => [time3, time1]}
    end

    test "handles terminal platform stop IDs" do
      {:ok, departures_pid} = Engine.Departures.start_link(gen_server_name: :departures_test)

      time1 = Timex.now()

      :ok =
        Engine.Departures.update_train_state(
          departures_pid,
          MapSet.new(["Alewife-02"]),
          time1
        )

      time2 = Timex.shift(time1, minutes: 3)

      :ok =
        Engine.Departures.update_train_state(
          departures_pid,
          MapSet.new(["Alewife-01", "Alewife-02"]),
          time2
        )

      time3 = Timex.shift(time2, minutes: 3)

      :ok =
        Engine.Departures.update_train_state(
          departures_pid,
          MapSet.new(["Alewife-01"]),
          time3
        )

      assert :sys.get_state(departures_pid).departures == %{"70061" => [time3]}

      time4 = Timex.shift(time3, minutes: 3)

      :ok =
        Engine.Departures.update_train_state(
          departures_pid,
          MapSet.new([]),
          time4
        )

      assert :sys.get_state(departures_pid).departures == %{"70061" => [time4, time3]}
    end

    test "when a departure is very quick assume that it is actually the real version of the previous departure" do
      {:ok, departures_pid} = Engine.Departures.start_link(gen_server_name: :departures_test)

      time1 = Timex.now()

      insert_test_data(departures_pid, "a", time1)

      time2 = Timex.shift(time1, minutes: 1)
      insert_test_data(departures_pid, "a", time2)

      assert :sys.get_state(departures_pid).departures == %{"a" => [time2]}
    end
  end

  describe "get_last_departure/2" do
    test "gets the  recorded departure time for the given stop" do
      {:ok, departures_pid} = Engine.Departures.start_link(gen_server_name: :departures_test)

      time1 = Timex.now()

      insert_test_data(departures_pid, "a", time1)

      assert Engine.Departures.get_last_departure(departures_pid, "a") == time1

      time2 = Timex.now()

      insert_test_data(departures_pid, "a", time2)

      assert Engine.Departures.get_last_departure(departures_pid, "a") == time2
    end
  end

  describe "get_headways/2" do
    test "handles case with no departure history" do
      {:ok, departures_pid} = Engine.Departures.start_link(gen_server_name: :departures_test)
      assert Engine.Departures.get_headways(departures_pid, "no_departures") == :none
    end

    test "when there is only one recorded departure, uses the scheduled headway" do
      time = Timex.now()

      {:ok, departures_pid} =
        Engine.Departures.start_link(
          gen_server_name: :departures_test,
          scheduled_headways_engine: FakeScheduledHeadwaysEngine,
          time_fetcher: fn -> Timex.to_datetime(~N[2019-09-02 12:15:00], "America/New_York") end
        )

      insert_test_data(departures_pid, "one_departure", time)

      assert Engine.Departures.get_headways(departures_pid, "one_departure") == {5, 10}
    end

    test "when there are two recorded departures, headway is the range between the two departures" do
      time1 = Timex.now()
      time2 = Timex.shift(time1, minutes: 5)
      {:ok, departures_pid} = Engine.Departures.start_link(gen_server_name: :departures_test)
      insert_test_data(departures_pid, "two_departures", time1)
      insert_test_data(departures_pid, "two_departures", time2)
      assert Engine.Departures.get_headways(departures_pid, "two_departures") == {5, nil}
    end

    test "when there are three recorded departures, headway is the range between the first two departures, and the range between the second two" do
      time1 = Timex.now()
      time2 = Timex.shift(time1, minutes: 5)
      time3 = Timex.shift(time2, minutes: 10)
      {:ok, departures_pid} = Engine.Departures.start_link(gen_server_name: :departures_test)
      insert_test_data(departures_pid, "three_departures", time1)
      insert_test_data(departures_pid, "three_departures", time2)
      insert_test_data(departures_pid, "three_departures", time3)
      assert Engine.Departures.get_headways(departures_pid, "three_departures") == {5, 10}
    end

    test "doesn't show headways before first departure" do
      time1 = Timex.to_datetime(~N[2019-09-01 23:30:00], "America/New_York")
      time2 = Timex.to_datetime(~N[2019-09-01 23:35:00], "America/New_York")

      {:ok, departures_pid} =
        Engine.Departures.start_link(
          gen_server_name: :departures_test,
          scheduled_headways_engine: FakeScheduledHeadwaysEngine,
          time_fetcher: fn -> Timex.to_datetime(~N[2019-09-02 04:00:00], "America/New_York") end
        )

      insert_test_data(departures_pid, "before_first_departure", time1)
      insert_test_data(departures_pid, "before_first_departure", time2)

      assert Engine.Departures.get_headways(departures_pid, "before_first_departure") == :none
    end

    test "doesn't show headways after last departure" do
      time1 = Timex.to_datetime(~N[2019-09-02 22:40:00], "America/New_York")
      time2 = Timex.to_datetime(~N[2019-09-02 22:50:00], "America/New_York")

      {:ok, departures_pid} =
        Engine.Departures.start_link(
          gen_server_name: :departures_test,
          scheduled_headways_engine: FakeScheduledHeadwaysEngine,
          time_fetcher: fn -> Timex.to_datetime(~N[2019-09-02 23:30:00], "America/New_York") end
        )

      insert_test_data(departures_pid, "after_last_departure", time1)
      insert_test_data(departures_pid, "after_last_departure", time2)

      assert Engine.Departures.get_headways(departures_pid, "after_last_departure") == :none
    end

    test "does show headways after first departure and before last departure" do
      time1 = Timex.to_datetime(~N[2019-09-02 12:00:00], "America/New_York")
      time2 = Timex.to_datetime(~N[2019-09-02 12:10:00], "America/New_York")

      {:ok, departures_pid} =
        Engine.Departures.start_link(
          gen_server_name: :departures_test,
          scheduled_headways_engine: FakeScheduledHeadwaysEngine,
          time_fetcher: fn -> Timex.to_datetime(~N[2019-09-02 12:15:00], "America/New_York") end
        )

      insert_test_data(departures_pid, "during_revenue_service", time1)
      insert_test_data(departures_pid, "during_revenue_service", time2)

      assert Engine.Departures.get_headways(departures_pid, "during_revenue_service") == {10, nil}
    end
  end

  describe "schedule_headways_reset/1" do
    test "resets the departures after the given amount of time" do
      {:ok, departures_pid} =
        Engine.Departures.start_link(
          gen_server_name: :departures_test,
          scheduled_headways_engine: FakeScheduledHeadwaysEngine,
          time_fetcher: fn -> Timex.to_datetime(~N[2019-09-02 12:15:00], "America/New_York") end
        )

      log =
        capture_log([level: :info], fn ->
          Engine.Departures.schedule_headways_reset(departures_pid, 10)
          Process.sleep(50)
        end)

      assert log =~ "daily_reset"
    end
  end

  defp insert_test_data(pid, stop_id, departure_time) do
    :ok =
      Engine.Departures.update_train_state(
        pid,
        [stop_id],
        departure_time
      )

    :ok =
      Engine.Departures.update_train_state(
        pid,
        [],
        departure_time
      )
  end
end
