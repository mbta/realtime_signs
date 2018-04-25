defmodule Content.Audio.NextTrainCountdownTest do
  use ExUnit.Case, async: true

  test "Next train to Ashmont" do
    audio = %Content.Audio.NextTrainCountdown{
      destination: :ashmont,
      minutes: 5,
    }
    assert Content.Audio.to_params(audio) == {"90", ["4016", "503", "5005"], :audio}
  end

  test "Next train to Mattapan" do
    audio = %Content.Audio.NextTrainCountdown{
      destination: :mattapan,
      minutes: 5,
    }
    assert Content.Audio.to_params(audio) == {"90", ["4100", "503", "5005"], :audio}
  end
end
