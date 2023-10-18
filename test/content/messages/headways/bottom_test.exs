defmodule Content.Message.Headways.BottomTest do
  use ExUnit.Case, async: true

  describe "to_string/1" do
    test "displays the range of times" do
      assert Content.Message.to_string(%Content.Message.Headways.Bottom{range: {1, 2}}) ==
               "Every 1 to 2 min"
    end
  end
end
