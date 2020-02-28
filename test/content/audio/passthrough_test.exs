defmodule Content.Audio.PassthroughTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Content.Audio.Passthrough

  describe "to_params/1" do
    test "Returns params" do
      audio = %Passthrough{destination: :alewife, route_id: "Red"}
      assert Content.Audio.to_params(audio) == {:canned, {"103", ["32114"], :audio_visual}}
    end

    test "Returns ad-hoc audio for valid destinations" do
      audio = %Passthrough{destination: :southbound, route_id: "Orange"}

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc,
                {"The next Southbound Orange Line train does not take customers", :audio}}
    end

    test "Returns nil for Green Line trips" do
      audio = %Passthrough{destination: :unknown, route_id: "Green-D"}
      log = capture_log([level: :info], fn -> assert Content.Audio.to_params(audio) == nil end)
      assert log =~ "unknown_passthrough_audio"
    end

    test "Returns nil when destination for which we don't have audio" do
      audio = %Passthrough{destination: :unknown, route_id: "Red"}
      log = capture_log([level: :info], fn -> assert Content.Audio.to_params(audio) == nil end)
      assert log =~ "unknown_passthrough_audio"
    end

    test "Returns nil when destination is Ashmont on the Mattapan line" do
      audio = %Passthrough{destination: :ashmont, route_id: "Mattapan"}
      assert Content.Audio.to_params(audio) == nil
    end
  end
end
