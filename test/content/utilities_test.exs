defmodule Content.UtilitiesTest do
  use ExUnit.Case, async: true

  import Content.Utilities

  describe "headsign_for_prediction/3" do
    test "handles child stops properly" do
      assert headsign_for_prediction("Red", 1, "Alewife-01") == {:ok, "Alewife"}
      assert headsign_for_prediction("Red", 1, "Alewife-02") == {:ok, "Alewife"}

      assert headsign_for_prediction("Red", 0, "Braintree-01") == {:ok, "Braintree"}
      assert headsign_for_prediction("Red", 0, "Braintree-02") == {:ok, "Braintree"}

      assert headsign_for_prediction("Orange", 0, "Forest Hills-01") == {:ok, "Frst Hills"}
      assert headsign_for_prediction("Orange", 0, "Forest Hills-02") == {:ok, "Frst Hills"}

      assert headsign_for_prediction("Orange", 1, "Oak Grove-01") == {:ok, "Oak Grove"}
      assert headsign_for_prediction("Orange", 1, "Oak Grove-02") == {:ok, "Oak Grove"}

      assert headsign_for_prediction("Green-D", 1, "Government Center-Brattle") ==
               {:ok, "Govt Ctr"}
    end

    test "Southbound headsign on Red Line trunk" do
      assert headsign_for_prediction("Red", 0, "70063") == {:ok, "Southbound"}
    end

    test "Regular headsigns for regular Red Line trips to Ashmont / Braintree" do
      assert headsign_for_prediction("Red", 0, "70093") == {:ok, "Ashmont"}
      assert headsign_for_prediction("Red", 0, "70105") == {:ok, "Braintree"}
    end

    test "Dont show kenmore on signs when the destination is blandford st" do
      assert headsign_for_prediction("Green-B", 0, "70149") == {:ok, "Boston Col"}
    end
  end

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
