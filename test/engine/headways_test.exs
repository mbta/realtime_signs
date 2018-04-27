defmodule Engine.HeadwaysTest do
  use ExUnit.Case
  describe "register callback" do
    test "adds the stop id to the state" do
      assert Engine.Headways.handle_call({:register, "123"}, %{}, %{}) == {:reply, %{"123" => []}, %{"123" => []}}
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
      schedules = Enum.map(@times, fn time ->
        %{"relationships" => %{"stop" => %{"data" => %{"id" => "123"}}},
          "attributes" => %{"departure_time" => Timex.format!(Timex.to_datetime(time, "America/New_York"), "{ISO:Extended}")}}
      end)
      state = %{"123" => schedules}
      assert Engine.Headways.handle_call({:get_headways, "123", current_time}, self(), state) == {:reply, {10, 17}, state}
    end
  end
end
