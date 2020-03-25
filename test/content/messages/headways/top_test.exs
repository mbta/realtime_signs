defmodule Content.Message.Headways.TopTest do
  use ExUnit.Case, async: true

  describe "to_string/1" do
    test "when the message has a headsign and a vehicle type, displays a top line message" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{
               destination: :mattapan,
               vehicle_type: :bus
             }) == "Buses to Mattapan"
    end

    test "correctly makes a message for trolleys" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{
               destination: :mattapan,
               vehicle_type: :trolley
             }) == "Mattapan trolleys"
    end

    test "Shows directionbound headsigns in a way that makes sense in english" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{
               destination: :northbound,
               vehicle_type: :trolley
             }) == "Northbound trolleys"

      assert Content.Message.to_string(%Content.Message.Headways.Top{
               destination: :southbound,
               vehicle_type: :trolley
             }) == "Southbound trolleys"

      assert Content.Message.to_string(%Content.Message.Headways.Top{
               destination: :eastbound,
               vehicle_type: :trolley
             }) == "Eastbound trolleys"

      assert Content.Message.to_string(%Content.Message.Headways.Top{
               destination: :westbound,
               vehicle_type: :trolley
             }) == "Westbound trolleys"
    end

    test "Forest Hills trains are displayed as Frst Hills trains" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{
               destination: :forest_hills,
               vehicle_type: :train
             }) == "Frst Hills trains"
    end

    test "Shows the right message when no destination" do
      assert Content.Message.to_string(%Content.Message.Headways.Top{
               destination: nil,
               vehicle_type: :train
             }) == "Trains"
    end
  end
end
