defmodule Content.Audio.FollowingTrainTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "Content.Audio.to_params protocol" do
    test "Following train to Ashmont" do
      audio = %Content.Audio.FollowingTrain{
        destination: :ashmont,
        verb: :arrives,
        minutes: 5
      }

      assert Content.Audio.to_params(audio) == {:canned, {"160", ["4016", "503", "5005"], :audio}}
    end

    test "When we dont have a good headsign, logs a warning" do
      message = %Content.Message.Predictions{headsign: "Neverland", minutes: 5}

      log =
        capture_log([level: :warn], fn ->
          assert Content.Audio.FollowingTrain.from_predictions_message(
                   {%{
                      terminal?: false,
                      platform: nil
                    }, message}
                 ) == nil
        end)

      assert log =~ "unknown headsign"
    end

    test "When we dont have a good headsign and its a terminal, logs a warning" do
      message = %Content.Message.Predictions{headsign: "Neverland", minutes: 5}

      log =
        capture_log([level: :warn], fn ->
          assert Content.Audio.FollowingTrain.from_predictions_message(
                   {%{
                      terminal?: true,
                      platform: nil
                    }, message}
                 ) == nil
        end)

      assert log =~ "unknown headsign"
    end

    test "when its a non terminal it uses arrives" do
      message = %Content.Message.Predictions{headsign: "Ashmont", minutes: 5}

      audio =
        Content.Audio.FollowingTrain.from_predictions_message(
          {%{
             terminal?: false,
             platform: nil
           }, message}
        )

      assert audio == %Content.Audio.FollowingTrain{
               destination: :ashmont,
               minutes: 5,
               verb: :arrives
             }
    end

    test "when its a terminal it uses departs" do
      message = %Content.Message.Predictions{headsign: "Ashmont", minutes: 5}

      audio =
        Content.Audio.FollowingTrain.from_predictions_message(
          {%{
             terminal?: true,
             platform: nil
           }, message}
        )

      assert audio == %Content.Audio.FollowingTrain{
               destination: :ashmont,
               minutes: 5,
               verb: :departs
             }
    end

    test "when its 1 minute, uses the right singular announcement" do
      audio = %Content.Audio.FollowingTrain{
        destination: :ashmont,
        verb: :arrives,
        minutes: 1
      }

      assert Content.Audio.to_params(audio) == {:canned, {"159", ["4016", "503"], :audio}}
    end

    test "returns ad_hoc audio when the destination is 'southbound'" do
      audio = %Content.Audio.FollowingTrain{
        destination: :southbound,
        verb: :arrives,
        minutes: 3
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc, {"The following southbound train arrives in 3 minutes", :audio}}
    end
  end
end
