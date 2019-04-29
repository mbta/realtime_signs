defmodule Content.Audio.ApproachingTest do
  use ExUnit.Case, async: true

  describe "to_params/1" do
    test "Returns the dummy value" do
      audio = %Content.Audio.Approaching{destination: :forest_hills}
      assert Content.Audio.to_params(audio) == {"123", [], :audio_visual}
    end
  end
end
