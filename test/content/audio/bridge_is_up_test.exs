defmodule Content.Audio.BridgeIsUpTest do
  use ExUnit.Case, async: true

  import Content.Audio.BridgeIsUp

  test "Bridge is up (no time estimate) in English" do
    audio = %Content.Audio.BridgeIsUp{
      language: :english,
      time_estimate_mins: nil
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
      time_estimate_mins: nil
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

  describe "create_bridge_messages/1" do
    test "returns an audio message from a headway message to chelsea" do
      assert {
        %Content.Audio.BridgeIsUp{language: :english, time_estimate_mins: 5},
        %Content.Audio.BridgeIsUp{language: :spanish, time_estimate_mins: 5}
      } = create_bridge_messages(5)
    end
  end
end
