defmodule Engine.Config.HeadwayTest do
  use ExUnit.Case, async: true
  alias Engine.Config.Headway

  describe "current_time_period/1" do
    test "correctly determines day" do
      assert DateTime.new!(~D[2020-03-20], ~T[06:00:00], "America/New_York")
             |> Headway.current_time_period() == :weekday

      assert DateTime.new!(~D[2020-03-21], ~T[02:00:00], "America/New_York")
             |> Headway.current_time_period() == :weekday

      assert DateTime.new!(~D[2020-03-21], ~T[04:00:00], "America/New_York")
             |> Headway.current_time_period() == :saturday

      assert DateTime.new!(~D[2020-03-22], ~T[08:00:00], "America/New_York")
             |> Headway.current_time_period() == :sunday
    end
  end
end
