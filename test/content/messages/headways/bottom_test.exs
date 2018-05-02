defmodule Content.Message.Headways.BottomTest do
  use ExUnit.Case, async: true

  describe "to_string/1" do
    test "displays the range of times" do
      assert Content.Message.to_string(%Content.Message.Headways.Bottom{range: {1, 2}}) ==
        "Every 1 to 2 min"
    end

    test "when the time is the same it only shows one time" do
      assert Content.Message.to_string(%Content.Message.Headways.Bottom{range: {2, 2}}) ==
        "Every 2 min"
    end

    test "when the message is a first departure message, still shows the range" do
      assert Content.Message.to_string(%Content.Message.Headways.Bottom{range: {:first_departure, {2, 2}, Timex.now()}}) ==
        "Every 2 min"
    end
  end
end
