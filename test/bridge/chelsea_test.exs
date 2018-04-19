defmodule Bridge.ChelseaTest do
  use ExUnit.Case, async: true
  import Bridge.Chelsea

  describe "raised/1" do
    test "returns true for raised status" do
      assert raised?({"Raised", 5})
    end

    test "returns false for lowered or nil status" do
      refute raised?({"Lowered", nil})
      refute raised?({nil, nil})
      refute raised?(nil)
    end
  end

  describe "get_duration/1" do
    test "gets duration in seconds" do
      current_time = ~N[2017-07-04 09:00:00] |> Timex.to_datetime("America/New_York")
      {:ok, estimate_time} = current_time
                             |> Timex.shift(minutes: 5)
                             |> Timex.format("{ISO:Extended}")
      duration = get_duration(estimate_time, current_time)
      assert duration == 300
    end

    test "returns nil for bad time string" do
      current_time = ~N[2017-07-04 09:00:00] |> Timex.to_datetime("America/New_York")
      duration = get_duration("bad time string", current_time)
      assert duration == nil
    end
  end
end
