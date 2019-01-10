defmodule Content.Audio.TrainIsBoardingTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "Content.Audio.to_params protocol" do
    test "Next train to Riverside is now boarding" do
      audio = %Content.Audio.TrainIsBoarding{destination: :riverside, route_id: "Green-D"}

      assert Content.Audio.to_params(audio) ==
               {"109", ["501", "538", "507", "4084", "544"], :audio}
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
