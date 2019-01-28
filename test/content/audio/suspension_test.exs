defmodule Content.Audio.SuspensionTest do
  use ExUnit.Case, async: true

  import Content.Audio.Suspension

  describe "from_messages/2" do
    test "Non-suspension messages" do
      assert from_messages(%Content.Message.Empty{}, %Content.Message.Empty{}) == nil
    end

    test "Station closed due to shuttle" do
      assert from_messages(
               %Content.Message.Alert.NoService{mode: :train},
               %Content.Message.Alert.UseShuttleBus{}
             ) == %Content.Audio.Suspension{alert: :shuttles_closed_station}
    end

    test "Station closed due to suspension" do
      assert from_messages(
               %Content.Message.Alert.NoService{mode: :train},
               %Content.Message.Empty{}
             ) == %Content.Audio.Suspension{alert: :suspension}
    end
  end

  describe "to_params/1" do
    test "Use shuttle audio" do
      assert Content.Audio.to_params(%Content.Audio.Suspension{
               alert: :shuttles_closed_station
             }) == {"123", [], :audio}
    end

    test "Station closed audio" do
      assert Content.Audio.to_params(%Content.Audio.Suspension{
               alert: :suspension
             }) == {"456", [], :audio}
    end
  end
end
