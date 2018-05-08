defmodule Content.Audio.BridgeIsUpTest do
  use ExUnit.Case, async: true

  import Content.Audio.BridgeIsUp

  test "Bridge is up (no time estimate) in English" do
    audio = %Content.Audio.BridgeIsUp{
      language: :english,
      time_estimate_mins: :soon
    }
    assert Content.Audio.to_params(audio) == {"136", [], :audio_visual}
  end

  test "Bridge is up (with a time estimate of 5 minutes) in English" do
    audio = %Content.Audio.BridgeIsUp{
      language: :english,
      time_estimate_mins: 5
    }
    assert Content.Audio.to_params(audio) == {"135", ["5505"], :audio_visual}
  end

  test "Bridge is up (no time estimate) in Spanish" do
    audio = %Content.Audio.BridgeIsUp{
      language: :spanish,
      time_estimate_mins: :soon
    }
    assert Content.Audio.to_params(audio) == {"157", [], :audio_visual}
  end

  test "Bridge is up (with a time estimate of 5 minutes) in Spanish" do
    audio = %Content.Audio.BridgeIsUp{
      language: :spanish,
      time_estimate_mins: 5
    }
    assert Content.Audio.to_params(audio) == {"152", ["37005"], :audio_visual}
  end

  # describe "from_headway_message/2" do
  #   @msg %Content.Message.Headways.Bottom{range: {5, 7}}
  #
  #   test "returns an audio message from a headway message to chelsea" do
  #     assert {
  #       %Content.Audio.BusesToDestination{language: :english, destination: :chelsea},
  #       %Content.Audio.BusesToDestination{language: :spanish, destination: :chelsea}
  #     } = from_headway_message(@msg, "Chelsea")
  #   end
  #
  #   test "returns an audio message from a headway message to south station" do
  #     assert {
  #       %Content.Audio.BusesToDestination{language: :english, destination: :south_station},
  #       %Content.Audio.BusesToDestination{language: :spanish, destination: :south_station}
  #     } = from_headway_message(@msg, "South Station")
  #   end
  #
  #   test "returns nil for an unknown destination" do
  #     assert from_headway_message(@msg, "Unknown") == nil
  #   end
  #
  #   test "returns nil when range is all nil" do
  #     msg = %{@msg | range: {nil, nil}}
  #     assert from_headway_message(msg, "Chelsea") == nil
  #   end
  #
  #   test "returns nil when range is unexpected" do
  #     msg = %{@msg | range: {:a, :b, :c}}
  #     assert from_headway_message(msg, "Chelsea") == nil
  #   end
  #
  #   test "returns a padded range when one value is missing or values are the same" do
  #     msg1 = %{@msg | range: {10, nil}}
  #     msg2 = %{@msg | range: {nil, 10}}
  #     msg3 = %{@msg | range: {10, 10}}
  #
  #     Enum.each([msg1, msg2, msg3], fn msg ->
  #       assert {
  #         %Content.Audio.BusesToDestination{language: :english, next_bus_mins: 10, later_bus_mins: 12},
  #         %Content.Audio.BusesToDestination{language: :spanish, next_bus_mins: 10, later_bus_mins: 12}
  #       } = from_headway_message(msg, "Chelsea")
  #     end)
  #   end
  #
  #   test "returns audio with values in ascending order regardless of range order" do
  #     msg1 = %{@msg | range: {10, 15}}
  #     msg2 = %{@msg | range: {15, 10}}
  #
  #     Enum.each([msg1, msg2], fn msg ->
  #       assert {
  #         %Content.Audio.BusesToDestination{language: :english, next_bus_mins: 10, later_bus_mins: 15},
  #         %Content.Audio.BusesToDestination{language: :spanish, next_bus_mins: 10, later_bus_mins: 15}
  #       } = from_headway_message(msg, "Chelsea")
  #     end)
  #   end
  # end
end
