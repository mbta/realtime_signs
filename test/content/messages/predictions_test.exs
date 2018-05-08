defmodule Content.Message.PredictionsTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "puts boarding on the sign when train is 0 seconds away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 0
      }
      msg = Content.Message.Predictions.new(prediction, "Ashmont")

      assert Content.Message.to_string(msg) == "Ashmont        BRD"
    end

    test "puts arriving on the sign when train is 0-60 seconds away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 45
      }
      msg = Content.Message.Predictions.new(prediction, "Mattapan")

      assert Content.Message.to_string(msg) == "Mattapan       ARR"
    end

    test "can use a shorter line length" do
      prediction = %Predictions.Prediction{seconds_until_arrival: 550}
      msg = Content.Message.Predictions.new(prediction, "Mattapan", 15)
      assert Content.Message.to_string(msg) == "Mattapan  9 min"
    end

    test "1 minute (singular) prediction" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 65
      }
      msg = Content.Message.Predictions.new(prediction, "Ashmont")

      assert Content.Message.to_string(msg) == "Ashmont      1 min"
    end

    test "multiple minutes prediction" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 125
      }
      msg = Content.Message.Predictions.new(prediction, "Ashmont")

      assert Content.Message.to_string(msg) == "Ashmont      2 min"
    end

    test "truncates very long headsigns to fit" do
      prediction = %Predictions.Prediction{seconds_until_arrival: 125}
      msg = Content.Message.Predictions.new(prediction, "ABCDEFGHIJKLMNOPQRSTUVWXYZ")

      assert Content.Message.to_string(msg) == "ABCDEFGHIJK  2 min"
    end

    test "handles invalid strings" do
      prediction = %Predictions.Prediction{seconds_until_arrival: -5}
      msg = Content.Message.Predictions.new(prediction, "abc")

      assert Content.Message.to_string(msg) == ""
    end
  end
end
