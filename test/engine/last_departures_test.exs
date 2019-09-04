defmodule Engine.LastDeparturesTest do
  use ExUnit.Case

  describe "add_departure/2" do
    test "records the most recent departure at a stop id" do
      time = Timex.now()
      assert %{"70001" => ^time} = Engine.LastDepartures.add_departure("70001", time)
      time2 = Timex.now()

      assert %{
               "70001" => ^time,
               "70003" => ^time2
             } = Engine.LastDepartures.add_departure("70003", time2)

      time3 = Timex.now()

      assert %{
               "70001" => ^time3,
               "70003" => ^time2
             } = Engine.LastDepartures.add_departure("70001", time3)
    end
  end

  describe "get_last_departure/1" do
    test "gets the last recorded departure time for the given stop" do
      time = Timex.now()
      Engine.LastDepartures.add_departure("70001", time)
      assert Engine.LastDepartures.get_last_departure("70001") == time
    end
  end
end
