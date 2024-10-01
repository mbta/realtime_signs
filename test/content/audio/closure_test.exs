defmodule Content.Audio.ClosureTest do
  use ExUnit.Case, async: true

  import Content.Audio.Closure

  describe "from_messages/2" do
    test "Non-suspension messages" do
      assert from_messages(%Content.Message.Empty{}, %Content.Message.Empty{}) == []
    end

    test "Station closed due to shuttle" do
      assert from_messages(
               %Content.Message.Alert.NoService{},
               %Content.Message.Alert.UseShuttleBus{}
             ) == [%Content.Audio.Closure{alert: :shuttles_closed_station}]
    end

    test "Station closed due to suspension" do
      assert from_messages(
               %Content.Message.Alert.NoService{},
               %Content.Message.Empty{}
             ) == [%Content.Audio.Closure{alert: :suspension_closed_station}]
    end
  end

  describe "to_params/1" do
    test "Default to train service for shuttle alert" do
      assert Content.Audio.to_params(%Content.Audio.Closure{
               alert: :shuttles_closed_station
             }) == {:canned, {"199", ["864"], :audio}}
    end

    test "Default to train service for suspension alert" do
      assert Content.Audio.to_params(%Content.Audio.Closure{
               alert: :suspension_closed_station
             }) == {:canned, {"107", ["861", "21000", "864", "21000", "863"], :audio}}
    end

    test "There is no [single line] service at this station, use shuttle bus" do
      assert Content.Audio.to_params(%Content.Audio.Closure{
               alert: :shuttles_closed_station,
               route: "Orange"
             }) == {:canned, {"199", ["3006"], :audio}}
    end

    test "There is no [single line] service at this station" do
      assert Content.Audio.to_params(%Content.Audio.Closure{
               alert: :suspension_closed_station,
               route: "Orange"
             }) == {:canned, {"107", ["861", "21000", "3006", "21000", "863"], :audio}}
    end

    test "Default to train service when different lines for shuttle alert" do
      assert Content.Audio.to_params(%Content.Audio.Closure{
               alert: :shuttles_closed_station,
               route: nil
             }) == {:canned, {"199", ["864"], :audio}}
    end

    test "Default to train service when different lines for suspension alert" do
      assert Content.Audio.to_params(%Content.Audio.Closure{
               alert: :suspension_closed_station,
               route: nil
             }) == {:canned, {"107", ["861", "21000", "864", "21000", "863"], :audio}}
    end

    test "Handle Green Line branches for shuttle alert" do
      assert Content.Audio.to_params(%Content.Audio.Closure{
               alert: :shuttles_closed_station,
               route: "Green"
             }) == {:canned, {"199", ["3008"], :audio}}
    end

    test "Handle Green Line branches for suspension alert" do
      assert Content.Audio.to_params(%Content.Audio.Closure{
               alert: :suspension_closed_station,
               route: "Green"
             }) == {:canned, {"107", ["861", "21000", "3008", "21000", "863"], :audio}}
    end
  end
end
