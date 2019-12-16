defmodule Content.Audio.BridgeIsUpTest do
  use ExUnit.Case, async: true

  import Content.Audio.BridgeIsUp

  test "Bridge is up (no time estimate) in English" do
    audio = %Content.Audio.BridgeIsUp{
      language: :english,
      time_estimate_mins: nil
    }

    assert Content.Audio.to_params(audio) == {:canned, {"136", [], :audio_visual, 5}}
  end

  test "Bridge is up (with a time estimate of 5 minutes) in English" do
    audio = %Content.Audio.BridgeIsUp{
      language: :english,
      time_estimate_mins: 5
    }

    assert Content.Audio.to_params(audio) == {:canned, {"135", ["5505"], :audio_visual, 5}}
  end

  test "Bridge is up (no time estimate) in Spanish" do
    audio = %Content.Audio.BridgeIsUp{
      language: :spanish,
      time_estimate_mins: nil
    }

    assert Content.Audio.to_params(audio) == {:canned, {"157", [], :audio_visual, 5}}
  end

  test "Bridge is up (with a time estimate of 5 minutes) in Spanish" do
    audio = %Content.Audio.BridgeIsUp{
      language: :spanish,
      time_estimate_mins: 5
    }

    assert Content.Audio.to_params(audio) == {:canned, {"152", ["37005"], :audio_visual, 5}}
  end

  test "When bridge is up with an estimate of 21 minutes, exclude time in Spanish audio" do
    audio = %Content.Audio.BridgeIsUp{
      language: :spanish,
      time_estimate_mins: 21
    }

    assert Content.Audio.to_params(audio) == {:canned, {"152", [], :audio_visual, 5}}
  end

  describe "create_bridge_messages/1" do
    test "returns an audio message from a headway message to chelsea" do
      assert {
               %Content.Audio.BridgeIsUp{language: :english, time_estimate_mins: 5},
               %Content.Audio.BridgeIsUp{language: :spanish, time_estimate_mins: 5}
             } = create_bridge_messages(5)
    end

    test "returns nil if minutes is out of range for audio" do
      assert {
               %Content.Audio.BridgeIsUp{language: :english, time_estimate_mins: 30},
               nil
             } = create_bridge_messages(30)
    end
  end
end
