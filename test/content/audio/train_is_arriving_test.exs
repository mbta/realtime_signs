defmodule Content.Audio.TrainIsArrivingTest do
  use ExUnit.Case, async: true

  describe "Content.Audio.to_params protocol" do
    test "Next train to Ashmont is now arriving" do
      audio = %Content.Audio.TrainIsArriving{destination: :ashmont}
      assert Content.Audio.to_params(audio) == {"90129", [], :audio_visual}
    end

    test "Next train to Mattapan is now arriving" do
      audio = %Content.Audio.TrainIsArriving{destination: :mattapan}
      assert Content.Audio.to_params(audio) == {"90128", [], :audio_visual}
    end

    test "Next train to Wonderland is now arriving" do
      audio = %Content.Audio.TrainIsArriving{destination: :wonderland}
      assert Content.Audio.to_params(audio) == {"90039", [], :audio_visual}
    end

    test "Next train to Bowdoin is now arriving" do
      audio = %Content.Audio.TrainIsArriving{destination: :bowdoin}
      assert Content.Audio.to_params(audio) == {"90040", [], :audio_visual}
    end
  end
end
