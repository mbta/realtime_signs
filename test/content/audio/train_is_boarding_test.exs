defmodule Content.Audio.TrainIsBoardingTest do
  use ExUnit.Case, async: true

  describe "Content.Audio.to_params protocol" do
    test "Next D train to Riverside is now boarding" do
      audio = %Content.Audio.TrainIsBoarding{
        destination: :riverside,
        route_id: "Green-D",
        track_number: nil
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"111", ["501", "21000", "538", "21000", "507", "21000", "4084", "21000", "544"],
                 :audio}}
    end

    test "Next train to North Station is now boarding (no branch letter for EB trains)" do
      audio = %Content.Audio.TrainIsBoarding{
        destination: :north_station,
        route_id: "Green-C",
        track_number: nil
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"109", ["501", "21000", "507", "21000", "4027", "21000", "544"], :audio}}
    end

    test "Next train to Alewife is now boarding (works on Heavy Rail)" do
      audio = %Content.Audio.TrainIsBoarding{
        destination: :alewife,
        route_id: "Red",
        track_number: nil
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"109", ["501", "21000", "507", "21000", "4000", "21000", "544"], :audio}}
    end

    test "announces track number at terminal with multiple boarding tracks" do
      audio = %Content.Audio.TrainIsBoarding{
        destination: :ashmont,
        route_id: "Red",
        track_number: 2
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"111", ["501", "21000", "507", "21000", "4016", "21000", "544", "21000", "542"],
                 :audio}}
    end
  end
end
