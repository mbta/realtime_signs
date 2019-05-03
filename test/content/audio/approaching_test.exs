defmodule Content.Audio.ApproachingTest do
  use ExUnit.Case, async: true

  alias Content.Audio.Approaching

  describe "to_params/1" do
    test "Returns params when platform is present" do
      audio = %Approaching{destination: :alewife, platform: :braintree, route_id: "Red"}
      assert Content.Audio.to_params(audio) == {"103", ["32126"], :audio_visual}
    end

    test "Returns params when platform is not present" do
      audio = %Approaching{destination: :oak_grove, route_id: "Orange"}
      assert Content.Audio.to_params(audio) == {"103", ["32122"], :audio_visual}
    end

    test "Returns nil when destination for which we don't have audio" do
      audio = %Approaching{destination: :riverside, route_id: "Green-D"}
      assert Content.Audio.to_params(audio) == nil
    end

    test "Returns nil when destination is Ashmont on the Mattapan line" do
      audio = %Approaching{destination: :ashmont, route_id: "Mattapan"}
      assert Content.Audio.to_params(audio) == nil
    end
  end
end
