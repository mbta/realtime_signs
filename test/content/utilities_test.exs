defmodule Content.UtilitiesTest do
  use ExUnit.Case, async: true

  import Content.Utilities

  describe "destination_for_prediction/3" do
    test "handles child stops properly" do
      assert destination_for_prediction(%{
               route_id: "Red",
               direction_id: 1,
               destination_stop_id: "Alewife-01"
             }) == :alewife

      assert destination_for_prediction(%{
               route_id: "Red",
               direction_id: 1,
               destination_stop_id: "Alewife-02"
             }) == :alewife

      assert destination_for_prediction(%{
               route_id: "Red",
               direction_id: 0,
               destination_stop_id: "Braintree-01"
             }) == :braintree

      assert destination_for_prediction(%{
               route_id: "Red",
               direction_id: 0,
               destination_stop_id: "Braintree-02"
             }) == :braintree

      assert destination_for_prediction(%{
               route_id: "Orange",
               direction_id: 0,
               destination_stop_id: "Forest Hills-01"
             }) == :forest_hills

      assert destination_for_prediction(%{
               route_id: "Orange",
               direction_id: 0,
               destination_stop_id: "Forest Hills-02"
             }) == :forest_hills

      assert destination_for_prediction(%{
               route_id: "Orange",
               direction_id: 1,
               destination_stop_id: "Oak Grove-01"
             }) == :oak_grove

      assert destination_for_prediction(%{
               route_id: "Orange",
               direction_id: 1,
               destination_stop_id: "Oak Grove-02"
             }) == :oak_grove

      assert destination_for_prediction(%{
               route_id: "Green-D",
               direction_id: 0,
               destination_stop_id: "Government Center-Brattle"
             }) ==
               :government_center

      assert destination_for_prediction(%{
               route_id: "Green-E",
               direction_id: 1,
               destination_stop_id: "71199"
             }) == :park_street
    end

    test "Southbound headsign on Red Line trunk" do
      assert destination_for_prediction(%{
               route_id: "Red",
               direction_id: 0,
               destination_stop_id: "70063"
             }) == :southbound
    end

    test "Regular headsigns for regular Red Line trips to Ashmont / Braintree" do
      assert destination_for_prediction(%{
               route_id: "Red",
               direction_id: 0,
               destination_stop_id: "70093"
             }) == :ashmont

      assert destination_for_prediction(%{
               route_id: "Red",
               direction_id: 0,
               destination_stop_id: "70105"
             }) == :braintree
    end

    test "Dont show kenmore on signs when the destination is blandford st" do
      assert destination_for_prediction(%{
               route_id: "Green-B",
               direction_id: 0,
               destination_stop_id: "70149"
             }) == :boston_college
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
