defmodule Content.UtilitiesTest do
  use ExUnit.Case, async: true

  import Content.Utilities

  describe "width_padded_string/3" do
    test "inserts spaces between left and right to reach given width" do
      assert width_padded_string("L", "R", 4) == "L  R"
    end

    test "enforces a minimum spacing between the two strings of 1" do
      assert width_padded_string("Left", "Right", 9) == "Lef Right"
    end
  end

  describe "stop_track_number/1" do
    test "returns track number for multi-track terminal" do
      assert stop_track_number("Alewife-01") == 1
    end

    test "returns nil for other stops" do
      assert stop_track_number("70063") == nil
    end
  end
end
