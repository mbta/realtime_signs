defmodule Content.Audio.TrainIsArrivingTest do
  use ExUnit.Case, async: true

  test "Next train to Ashmont is now arriving" do
    audio = %Content.Audio.TrainIsArriving{destination: :ashmont}
    assert Content.Audio.to_params(audio) == {"90129", []}
  end

  test "Next train to Mattapan is now arriving" do
    audio = %Content.Audio.TrainIsArriving{destination: :mattapan}
    assert Content.Audio.to_params(audio) == {"90128", []}
  end
end
