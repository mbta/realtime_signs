defmodule Content.Audio.StoppedAtStationTest do
  use ExUnit.Case, async: true

  describe "from_message/1" do
    test "converts a Message to an Audio" do
      assert %Content.Audio.StoppedAtStation{
               destination: :oak_grove,
               stopped_at: :wellington
             } =
               Content.Audio.StoppedAtStation.from_message(%Content.Message.StoppedAtStation{
                 destination: :oak_grove,
                 stopped_at: :wellington
               })
    end
  end

  describe "to_params/1" do
    test "converts an Audio to ARINC params" do
      assert {:canned, {"105", ["825", "21000", "830"], :audio}} =
               Content.Audio.to_params(%Content.Audio.StoppedAtStation{
                 destination: :oak_grove,
                 stopped_at: :downtown_crossing
               })
    end
  end
end
