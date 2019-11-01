defmodule Content.Audio.ClosureTest do
  use ExUnit.Case, async: true

  import Content.Audio.Closure

  describe "from_messages/2" do
    test "Non-suspension messages" do
      assert from_messages(%Content.Message.Empty{}, %Content.Message.Empty{}) == nil
    end

    test "Station closed due to shuttle" do
      assert from_messages(
               %Content.Message.Alert.NoService{mode: :train},
               %Content.Message.Alert.UseShuttleBus{}
             ) == %Content.Audio.Closure{alert: :shuttles_closed_station}
    end

    test "Station closed due to suspension" do
      assert from_messages(
               %Content.Message.Alert.NoService{mode: :train},
               %Content.Message.Empty{}
             ) == %Content.Audio.Closure{alert: :suspension_closed_station}
    end
  end

  describe "to_params/1" do
    test "Use shuttle audio" do
      assert Content.Audio.to_params(%Content.Audio.Closure{
               alert: :shuttles_closed_station
             }) == {:sign_content, {"90131", [], :audio}}
    end

    test "Station closed audio" do
      assert Content.Audio.to_params(%Content.Audio.Closure{
               alert: :suspension_closed_station
             }) == {:sign_content, {"90130", [], :audio}}
    end
  end
end
