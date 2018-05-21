defmodule Content.Audio.NextTrainCountdownTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "Content.Audio.to_params protocol" do
    test "Next train to Ashmont" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :ashmont,
        verb: :arrives,
        minutes: 5,
      }
      assert Content.Audio.to_params(audio) == {"90", ["4016", "503", "5005"], :audio}
    end

    test "Next train to Mattapan" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :mattapan,
        verb: :arrives,
        minutes: 5,
      }
      assert Content.Audio.to_params(audio) == {"90", ["4100", "503", "5005"], :audio}
    end

    test "Next train to Bowdoin" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :bowdoin,
        verb: :arrives,
        minutes: 5,
      }
      assert Content.Audio.to_params(audio) == {"90", ["4055", "503", "5005"], :audio}
    end

    test "Next train to Wonderland" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :wonderland,
        verb: :arrives,
        minutes: 5,
      }
      assert Content.Audio.to_params(audio) == {"90", ["4044", "503", "5005"], :audio}
    end
  end

  describe "from_predictions_message/1" do
    test "Converts Ashmont countdown message to audio" do
      message = %Content.Message.Predictions{headsign: "Ashmont", minutes: 5}
      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives) ==
        %Content.Audio.NextTrainCountdown{destination: :ashmont, verb: :arrives, minutes: 5}
    end

    test "Converts Mattapan countdown message to audio" do
      message = %Content.Message.Predictions{headsign: "Mattapan", minutes: 5}
      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives) ==
        %Content.Audio.NextTrainCountdown{destination: :mattapan, verb: :arrives, minutes: 5}
    end

    test "Converts Wonderland countdown message to audio" do
      message = %Content.Message.Predictions{headsign: "Wonderland", minutes: 5}
      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives) ==
        %Content.Audio.NextTrainCountdown{destination: :wonderland, verb: :arrives, minutes: 5}
    end

    test "Converts Bowdoin countdown message to audio" do
      message = %Content.Message.Predictions{headsign: "Bowdoin", minutes: 5}
      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives) ==
        %Content.Audio.NextTrainCountdown{destination: :bowdoin, verb: :arrives, minutes: 5}
    end

    test "Logs unknown headsign countdown message" do
      message = %Content.Message.Predictions{headsign: "Neverland", minutes: 5}

      log = capture_log [level: :warn], fn ->
        assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives) == nil
      end

      assert log =~ "unknown headsign"
    end

    test "Ignores non-integer messages" do
      message = %Content.Message.Predictions{headsign: "Ashmont", minutes: :arriving}
      assert Content.Audio.NextTrainCountdown.from_predictions_message(message, :arrives) == nil
    end
  end
end
