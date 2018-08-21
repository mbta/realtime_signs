defmodule Content.Audio.StoppedTrainTest do
  use ExUnit.Case, async: true

  describe "to_params/1" do
    test "Serializes correctly" do
      audio = %Content.Audio.StoppedTrain{destination: :alewife, stops_away: 2}
      assert Content.Audio.to_params(audio) ==
        {"109", ["501", "507", "4000", "533", "641", "5002", "534"]}
    end

    test "Uses singular 'stop' if 1 stop away" do
      audio = %Content.Audio.StoppedTrain{destination: :alewife, stops_away: 1}
      assert Content.Audio.to_params(audio) ==
        {"109", ["501", "507", "4000", "533", "641", "5001", "535"]}
    end
  end
end
