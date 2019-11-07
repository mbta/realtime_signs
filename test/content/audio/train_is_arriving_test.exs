defmodule Content.Audio.TrainIsArrivingTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "Content.Audio.to_params protocol" do
    test "Next train to Ashmont is now arriving" do
      audio = %Content.Audio.TrainIsArriving{destination: :ashmont, route_id: "Mattapan"}
      assert Content.Audio.to_params(audio) == {:canned, {"90129", [], :audio_visual}}
    end

    test "Next train to Mattapan is now arriving" do
      audio = %Content.Audio.TrainIsArriving{destination: :mattapan, route_id: "Mattapan"}
      assert Content.Audio.to_params(audio) == {:canned, {"90128", [], :audio_visual}}
    end

    test "Next train to Wonderland is now arriving" do
      audio = %Content.Audio.TrainIsArriving{destination: :wonderland, route_id: "Blue"}
      assert Content.Audio.to_params(audio) == {:canned, {"103", ["32100"], :audio_visual}}
    end

    test "Next train to Bowdoin is now arriving" do
      audio = %Content.Audio.TrainIsArriving{destination: :bowdoin, route_id: "Blue"}
      assert Content.Audio.to_params(audio) == {:canned, {"103", ["32101"], :audio_visual}}
    end

    test "Red line train to Ashmont" do
      audio = %Content.Audio.TrainIsArriving{destination: :ashmont, route_id: "Red"}
      assert Content.Audio.to_params(audio) == {:canned, {"103", ["32107"], :audio_visual}}
    end

    test "Red line train to Alewife" do
      audio = %Content.Audio.TrainIsArriving{
        destination: :alewife,
        route_id: "Red",
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {:canned, {"103", ["32104"], :audio_visual}}
    end

    test "Red line train to Alewife on Braintree platform" do
      audio = %Content.Audio.TrainIsArriving{
        destination: :alewife,
        route_id: "Red",
        platform: :braintree
      }

      assert Content.Audio.to_params(audio) == {:canned, {"103", ["32106"], :audio_visual}}
    end

    test "Southbound train" do
      audio = %Content.Audio.TrainIsArriving{destination: :southbound, route_id: "Red"}

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc,
                {"Attention passengers: The next southbound Red Line train is now arriving.",
                 :audio_visual}}
    end

    test "Handles unknown destination gracefully" do
      audio = %Content.Audio.TrainIsArriving{destination: :unknown, route_id: "Red"}

      log =
        capture_log([level: :error], fn ->
          assert Content.Audio.to_params(audio) == nil
        end)

      assert log =~ "unknown params"
    end
  end
end
