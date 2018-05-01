defmodule Content.Message.Headways.TopTest do
  use ExUnit.Case, async: true

  describe "to_string/1" do
    test "when the message has a headsign and a vehicle type, displays a top line message" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{headsign: "Mattapan", vehicle_type: :bus}) ==
        "Buses to Mattapan"
    end

    test "correctly makes a message for trolleys" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{headsign: "Mattapan", vehicle_type: :trolley}) ==
        "Trolleys to Mattapan"
    end

    test "shortens south station when that is the headsign" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{headsign: "South Station", vehicle_type: :trolley}) ==
        "Trolleys to South Sta"
    end
  end
end
