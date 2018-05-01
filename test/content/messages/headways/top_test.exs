defmodule Content.Message.Headways.TopTest do
  use ExUnit.Case, async: true

  describe "to_string/1" do
    test "when the message has a headsign and a vehicle type, displays a top line message" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{headsign: "Mattapan", vehicle_type: :bus}) ==
        "Buses to Mattapan"
    end
  end

  describe "signify_vehicle_type/1" do
    test "turns :bus into Buses" do
      assert Content.Message.Headways.Top.signify_vehicle_type(:bus) == "Buses"
    end

    test "turns :trolley into Trolleys" do
      assert Content.Message.Headways.Top.signify_vehicle_type(:trolley) == "Trolleys"
    end
  end
end
