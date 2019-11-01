defmodule Content.Audio.PassthroughTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Content.Audio.Passthrough

  describe "to_params/1" do
    test "Returns params" do
      audio = %Passthrough{destination: :alewife, route_id: "Red"}
      assert Content.Audio.to_params(audio) == {:sign_content, {"103", ["32114"], :audio_visual}}
    end

    test "Returns nil when destination for which we don't have audio" do
      audio = %Passthrough{destination: :riverside, route_id: "Green-D"}
      log = capture_log([level: :info], fn -> assert Content.Audio.to_params(audio) == nil end)
      assert log =~ "unknown_passthrough_audio"
    end

    test "Returns nil when destination is Ashmont on the Mattapan line" do
      audio = %Passthrough{destination: :ashmont, route_id: "Mattapan"}
      assert Content.Audio.to_params(audio) == nil
    end
  end
end
