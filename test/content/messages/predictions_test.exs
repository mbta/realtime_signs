defmodule Content.Message.PredictionsTest do
  use ExUnit.Case, async: true

  describe "non_terminal/3" do
    test "puts ARR on the sign when train is 0 seconds away, but not boarding" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 0
      }
      msg = Content.Message.Predictions.non_terminal(prediction, "Ashmont", false)

      assert Content.Message.to_string(msg) == "Ashmont        ARR"
    end

    test "puts BRD on the sign when train is currently boarding" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 0
      }
      msg = Content.Message.Predictions.non_terminal(prediction, "Ashmont", true)

      assert Content.Message.to_string(msg) == "Ashmont        BRD"
    end

    test "puts arriving on the sign when train is 0-30 seconds away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 30
      }
      msg = Content.Message.Predictions.non_terminal(prediction, "Mattapan", false)

      assert Content.Message.to_string(msg) == "Mattapan       ARR"
    end

    test "puts minutes on the sign when train is 31 seconds away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 31
      }
      msg = Content.Message.Predictions.non_terminal(prediction, "Mattapan", false)

      assert Content.Message.to_string(msg) == "Mattapan     1 min"
    end

    test "Says 30+ min when train is more than 30 minutes away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 45 * 60
      }
      msg = Content.Message.Predictions.non_terminal(prediction, "Mattapan", false)

      assert Content.Message.to_string(msg) == "Mattapan   30+ min"
    end

    test "Says 30 min when train is exactly 30 minutes away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 30 * 60
      }
      msg = Content.Message.Predictions.non_terminal(prediction, "Mattapan", false)

      assert Content.Message.to_string(msg) == "Mattapan    30 min"
    end

    test "can use a shorter line length" do
      prediction = %Predictions.Prediction{seconds_until_arrival: 550}
      msg = Content.Message.Predictions.non_terminal(prediction, "Mattapan", 15, false)
      assert Content.Message.to_string(msg) == "Mattapan  9 min"
    end

    test "1 minute (singular) prediction" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 65
      }
      msg = Content.Message.Predictions.non_terminal(prediction, "Ashmont", false)

      assert Content.Message.to_string(msg) == "Ashmont      1 min"
    end

    test "multiple minutes prediction" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 125
      }
      msg = Content.Message.Predictions.non_terminal(prediction, "Ashmont", false)

      assert Content.Message.to_string(msg) == "Ashmont      2 min"
    end

    test "truncates very long headsigns to fit" do
      prediction = %Predictions.Prediction{seconds_until_arrival: 125}
      msg = Content.Message.Predictions.non_terminal(prediction, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", false)

      assert Content.Message.to_string(msg) == "ABCDEFGHIJK  2 min"
    end

    test "Still shows predictions for negative arrivals" do
      prediction = %Predictions.Prediction{seconds_until_arrival: -5}
      msg = Content.Message.Predictions.non_terminal(prediction, "abc", false)

      assert Content.Message.to_string(msg) == "abc            ARR"
    end

    test "Shows BRD for negative arrival times if vehicle is STOPPED_AT" do
      prediction = %Predictions.Prediction{seconds_until_arrival: -5}
      msg = Content.Message.Predictions.non_terminal(prediction, "abc", true)

      assert Content.Message.to_string(msg) == "abc            BRD"
    end

    test "Rounds to the nearest minute" do
      prediction = %Predictions.Prediction{seconds_until_arrival: 91}
      msg = Content.Message.Predictions.non_terminal(prediction, "Ashmont", false)

      assert Content.Message.to_string(msg) == "Ashmont      2 min"
    end
  end

  describe "terminal/3" do
    test "puts boarding on the sign when train is currently boarding" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 0
      }
      msg = Content.Message.Predictions.terminal(prediction, "Ashmont", true)

      assert Content.Message.to_string(msg) == "Ashmont        BRD"
    end

    test "does not put boarding if prediction is greater than 30 seconds" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 45
      }
      msg = Content.Message.Predictions.terminal(prediction, "Ashmont", true)

      assert Content.Message.to_string(msg) == "Ashmont      1 min"
    end

    test "puts 1 min on the sign when train is not boarding, but less than a minute away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 10
      }
      msg = Content.Message.Predictions.terminal(prediction, "Ashmont", false)

      assert Content.Message.to_string(msg) == "Ashmont      1 min"
    end

    test "puts the time on the sign when train is more than 30 seconds away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 60
      }
      msg = Content.Message.Predictions.terminal(prediction, "Mattapan", false)

      assert Content.Message.to_string(msg) == "Mattapan     1 min"
    end
  end
end
