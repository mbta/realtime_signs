defmodule Engine.Config.HeadwayTest do
  use ExUnit.Case, async: true
  alias Engine.Config.Headway

  describe "from_map/2" do
    test "parses successfully" do
      assert Headway.from_map("A", "peak", %{"range_low" => 5, "range_high" => 10}) ==
               {:ok, %Headway{headway_id: {"A", :peak}, range_low: 5, range_high: 10}}
    end

    test "returns error for invalid data" do
      assert Headway.from_map("A", "peak", %{}) == :error
    end

    test "returns error for invalid time period" do
      assert Headway.from_map("A", "invalid", %{"range_low" => 5, "range_high" => 10}) == :error
    end
  end

  describe "current_time_period/1" do
    test "correctly determines peak and offpeak" do
      assert DateTime.new!(~D[2020-03-20], ~T[18:00:00], "America/New_York")
             |> Headway.current_time_period() == :peak

      assert DateTime.new!(~D[2020-03-21], ~T[02:00:00], "America/New_York")
             |> Headway.current_time_period() == :off_peak

      assert DateTime.new!(~D[2020-03-21], ~T[08:00:00], "America/New_York")
             |> Headway.current_time_period() == :saturday

      assert DateTime.new!(~D[2020-03-22], ~T[12:00:00], "America/New_York")
             |> Headway.current_time_period() == :sunday
    end
  end
end
