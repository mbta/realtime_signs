defmodule Engine.DeparturesTest do
  use ExUnit.Case

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

      time2 = Timex.now()

      :ok =
        Engine.Departures.update_train_state(
          departures_pid,
          stops3,
          time2
        )

      assert :sys.get_state(departures_pid).departures == %{"a" => [time2], "b" => [time1]}

      time3 = Timex.now()

      :ok =
        Engine.Departures.update_train_state(
          departures_pid,
          stops4,
          time3
        )

      assert :sys.get_state(departures_pid).departures == %{"a" => [time2], "b" => [time3, time1]}
    end
  end

  describe "get_last_departure/2" do
    test "gets the  recorded departure time for the given stop" do
      {:ok, departures_pid} = Engine.Departures.start_link(gen_server_name: :departures_test)
      stops1 = MapSet.new(["a", "b"])
      stops2 = MapSet.new(["a"])
      stops3 = MapSet.new(["b"])
      stops4 = MapSet.new(["a"])
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

      assert Engine.Departures.get_last_departure(departures_pid, "b") == time1

      time2 = Timex.now()

      :ok =
        Engine.Departures.update_train_state(
          departures_pid,
          stops3,
          time2
        )

      :ok =
        Engine.Departures.update_train_state(
          departures_pid,
          stops4,
          time2
        )

      assert Engine.Departures.get_last_departure(departures_pid, "b") == time2
    end
  end
end
