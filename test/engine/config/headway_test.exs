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
      dt1 = DateTime.from_naive!(~N[2020-03-20 06:00:00], "America/New_York")
      dt2 = DateTime.from_naive!(~N[2020-03-20 07:00:00], "America/New_York")
      dt3 = DateTime.from_naive!(~N[2020-03-20 07:45:00], "America/New_York")
      dt4 = DateTime.from_naive!(~N[2020-03-20 09:00:01], "America/New_York")
      dt5 = DateTime.from_naive!(~N[2020-03-20 12:00:00], "America/New_York")
      dt6 = DateTime.from_naive!(~N[2020-03-20 15:00:00], "America/New_York")
      dt7 = DateTime.from_naive!(~N[2020-03-20 16:00:00], "America/New_York")
      dt8 = DateTime.from_naive!(~N[2020-03-20 18:00:00], "America/New_York")
      dt9 = DateTime.from_naive!(~N[2020-03-20 18:20:00], "America/New_York")
      dt10 = DateTime.from_naive!(~N[2020-03-20 18:40:00], "America/New_York")
      dt11 = DateTime.from_naive!(~N[2020-03-21 06:00:00], "America/New_York")
      dt12 = DateTime.from_naive!(~N[2020-03-21 08:00:00], "America/New_York")

      assert Headway.current_time_period(dt1) == :off_peak
      assert Headway.current_time_period(dt2) == :peak
      assert Headway.current_time_period(dt3) == :peak
      assert Headway.current_time_period(dt4) == :off_peak
      assert Headway.current_time_period(dt5) == :off_peak
      assert Headway.current_time_period(dt6) == :off_peak
      assert Headway.current_time_period(dt7) == :peak
      assert Headway.current_time_period(dt8) == :peak
      assert Headway.current_time_period(dt9) == :peak
      assert Headway.current_time_period(dt10) == :off_peak
      assert Headway.current_time_period(dt11) == :off_peak
      assert Headway.current_time_period(dt12) == :off_peak
    end
  end
end
