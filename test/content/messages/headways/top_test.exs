defmodule Content.Message.Headways.TopTest do
  use ExUnit.Case, async: true

  describe "to_string/1" do
    test "when the message has a headsign and a vehicle type, displays a top line message" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{
               headsign: "Mattapan",
               vehicle_type: :bus
             }) == "Buses to Mattapan"
    end

    test "correctly makes a message for trolleys" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{
               headsign: "Mattapan",
               vehicle_type: :trolley
             }) == "Trolleys to Mattapan"
    end

    test "shortens south station when that is the headsign" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{
               headsign: "South Station",
               vehicle_type: :trolley
             }) == "Trolleys to South Sta"
    end

    test "Shows directionbound headsigns in a way that makes sense in english" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{
               headsign: "Northbound",
               vehicle_type: :trolley
             }) == "Northbound Trolleys"

      assert Content.Message.to_string(%Content.Message.Headways.Top{
               headsign: "Southbound",
               vehicle_type: :trolley
             }) == "Southbound Trolleys"

      assert Content.Message.to_string(%Content.Message.Headways.Top{
               headsign: "Eastbound",
               vehicle_type: :trolley
             }) == "Eastbound Trolleys"

      assert Content.Message.to_string(%Content.Message.Headways.Top{
               headsign: "Westbound",
               vehicle_type: :trolley
             }) == "Westbound Trolleys"
    end
  end
end
