defmodule Content.Message.Headways.TopTest do
  use ExUnit.Case

  describe "to_string/1" do
    test "when the message has a headsign and a vehicle type, displays a top line message" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{headsign: "Mattapan", vehicle_type: :bus}) ==
        "Buses to Mattapan"
    end
  end
end
