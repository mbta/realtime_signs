defmodule Content.Audio.TrainIsBoardingTest do
  use ExUnit.Case, async: true

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

    test "Next train to Alewife is now boarding (works on Heavy Rail)" do
      audio = %Content.Audio.TrainIsBoarding{destination: :alewife, route_id: "Red"}

      assert Content.Audio.to_params(audio) == {"106", ["501", "507", "4000", "544"], :audio}
    end
  end
end
