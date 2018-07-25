defmodule Content.Audio.NextTrainCountdownTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "Content.Audio.to_params protocol" do
    test "Next train to Ashmont" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :ashmont,
        verb: :arrives,
        minutes: 5,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4016", "503", "5005"], :audio}
    end

    test "Next train to Mattapan" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :mattapan,
        verb: :arrives,
        minutes: 5,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4100", "503", "5005"], :audio}
    end

    test "Next train to Bowdoin" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :bowdoin,
        verb: :arrives,
        minutes: 5,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4055", "503", "5005"], :audio}
    end

    test "Next train to Wonderland" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :wonderland,
        verb: :arrives,
        minutes: 5,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4044", "503", "5005"], :audio}
    end

    test "Next train to Forest Hills" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :forest_hills,
        verb: :arrives,
        minutes: 5,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4043", "503", "5005"], :audio}
    end

    test "Next train to Oak Grove" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :oak_grove,
        verb: :arrives,
        minutes: 5,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4022", "503", "5005"], :audio}
    end

    test "Next train to Alewife" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        verb: :arrives,
        minutes: 5,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4000", "503", "5005"], :audio}
    end

    test "Next train to Alewife on the Ashmont platform" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        verb: :arrives,
        minutes: 5,
        platform: :ashmont
      }

      assert Content.Audio.to_params(audio) == {"99", ["4000", "4016", "503", "5005"], :audio}
    end

    test "Next train to Alewife on the Braintree platform" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        verb: :arrives,
        minutes: 5,
        platform: :braintree
      }

      assert Content.Audio.to_params(audio) == {"99", ["4000", "4021", "503", "5005"], :audio}
    end

    test "Next train to Braintree" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :braintree,
        verb: :arrives,
        minutes: 5,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4021", "503", "5005"], :audio}
    end

    test "Uses audio for 30 minutes when train is more than 30 minutes away" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :wonderland,
        verb: :arrives,
        minutes: 50,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4044", "503", "5030"], :audio}
    end
  end

  describe "from_predictions_message/1" do
    test "Converts Ashmont countdown message to audio" do
      message = %Content.Message.Predictions{headsign: "Ashmont", minutes: 5}

      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives, nil) ==
               %Content.Audio.NextTrainCountdown{
                 destination: :ashmont,
                 verb: :arrives,
                 minutes: 5
               }
    end

    test "Converts Mattapan countdown message to audio" do
      message = %Content.Message.Predictions{headsign: "Mattapan", minutes: 5}

      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives, nil) ==
               %Content.Audio.NextTrainCountdown{
                 destination: :mattapan,
                 verb: :arrives,
                 minutes: 5
               }
    end

    test "Converts Wonderland countdown message to audio" do
      message = %Content.Message.Predictions{headsign: "Wonderland", minutes: 5}

      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives, nil) ==
               %Content.Audio.NextTrainCountdown{
                 destination: :wonderland,
                 verb: :arrives,
                 minutes: 5
               }
    end

    test "Converts Bowdoin countdown message to audio" do
      message = %Content.Message.Predictions{headsign: "Bowdoin", minutes: 5}

      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives, nil) ==
               %Content.Audio.NextTrainCountdown{
                 destination: :bowdoin,
                 verb: :arrives,
                 minutes: 5
               }
    end

    test "Converts Alewife countdown message to audio" do
      message = %Content.Message.Predictions{headsign: "Alewife", minutes: 5}

      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives, nil) ==
               %Content.Audio.NextTrainCountdown{
                 destination: :alewife,
                 verb: :arrives,
                 minutes: 5
               }
    end

    test "Converts Alewife countdown message on the at JFK/UMass (specifying platform) to audio" do
      message = %Content.Message.Predictions{headsign: "Alewife", minutes: 5}

      assert Content.Audio.NextTrainCountdown.from_predictions_message(
               message,
               :arrives,
               :ashmont
             ) ==
               %Content.Audio.NextTrainCountdown{
                 destination: :alewife,
                 verb: :arrives,
                 minutes: 5,
                 platform: :ashmont
               }
    end

    test "Converts Braintree countdown message to audio" do
      message = %Content.Message.Predictions{headsign: "Braintree", minutes: 5}

      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives, nil) ==
               %Content.Audio.NextTrainCountdown{
                 destination: :braintree,
                 verb: :arrives,
                 minutes: 5
               }
    end

    test "Logs unknown headsign countdown message" do
      message = %Content.Message.Predictions{headsign: "Neverland", minutes: 5}

      log =
        capture_log([level: :warn], fn ->
          assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives, nil) ==
                   nil
        end)

      assert log =~ "unknown headsign"
    end

    test "Does not announce train one minute away" do
      message = %Content.Message.Predictions{headsign: "Ashmont", minutes: 1}

      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives, nil) ==
               nil

      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :departs, nil) ==
               nil
    end

    test "Ignores non-integer messages" do
      message = %Content.Message.Predictions{headsign: "Ashmont", minutes: :arriving}

      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives, nil) ==
               nil
    end
  end
end
