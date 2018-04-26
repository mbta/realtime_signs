defmodule Content.Audio.TrainIsArrivingTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "Content.Audio.to_params protocol" do
    test "Next train to Ashmont is now arriving" do
      audio = %Content.Audio.TrainIsArriving{destination: :ashmont}
      assert Content.Audio.to_params(audio) == {"90129", [], :audio}
    end

    test "Next train to Mattapan is now arriving" do
      audio = %Content.Audio.TrainIsArriving{destination: :mattapan}
      assert Content.Audio.to_params(audio) == {"90128", [], :audio}
    end
  end

  describe "from_predictions_message/1" do
    test "Converts Ashmont arriving message to audio" do
      message = %Content.Message.Predictions{headsign: "Ashmont", minutes: :arriving}
      assert Content.Audio.TrainIsArriving.from_predictions_message(message) ==
        %Content.Audio.TrainIsArriving{destination: :ashmont}
    end

    test "Converts Mattapan arriving message to audio" do
      message = %Content.Message.Predictions{headsign: "Mattapan", minutes: :arriving}
      assert Content.Audio.TrainIsArriving.from_predictions_message(message) ==
        %Content.Audio.TrainIsArriving{destination: :mattapan}
    end

    test "Logs unknown headsign arriving message" do
      message = %Content.Message.Predictions{headsign: "Neverland", minutes: :arriving}

      log = capture_log [level: :warn], fn ->
        assert Content.Audio.TrainIsArriving.from_predictions_message(message) == nil
      end

      assert log =~ "unknown headsign"
    end

    test "Ignores non-arriving messages" do
      message = %Content.Message.Predictions{headsign: "Ashmont", minutes: 5}
      assert Content.Audio.TrainIsArriving.from_predictions_message(message) == nil
    end
  end
end
