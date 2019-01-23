defmodule Content.Audio.TrainIsBoardingTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "Content.Audio.to_params protocol" do
    test "Next D train to Riverside is now boarding" do
      audio = %Content.Audio.TrainIsBoarding{destination: :riverside, route_id: "Green-D"}

      assert Content.Audio.to_params(audio) ==
               {"107", ["501", "538", "507", "4084", "544"], :audio}
    end

    test "Next train to North Station is now boarding (no branch letter for EB trains)" do
      audio = %Content.Audio.TrainIsBoarding{destination: :north_station, route_id: "Green-C"}

      assert Content.Audio.to_params(audio) == {"106", ["501", "507", "4027", "544"], :audio}
    end
  end

  describe "from_message/1" do
    test "Converts Riverside arriving message to audio" do
      message = %Content.Message.Predictions{
        headsign: "Riverside",
        minutes: :boarding,
        stop_id: "70151",
        route_id: "Green-D"
      }

      assert Content.Audio.TrainIsBoarding.from_message(message) ==
               %Content.Audio.TrainIsBoarding{destination: :riverside, route_id: "Green-D"}
    end
  end
end
