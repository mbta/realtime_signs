defmodule Content.Message.StoppedTrainTest do
  use ExUnit.Case, async: true

  describe "to_string/1" do
    test "returns tuple of stopped away pages otherwise" do
      msg = %Content.Message.StoppedTrain{destination: :braintree, stops_away: 2}

      assert Content.Message.to_string(msg) ==
               [
                 {"Braintree  Stopped", 6},
                 {"Braintree  2 stops", 6},
                 {"Braintree     away", 6}
               ]
    end

    test "if only 1 stop away, doesn't pluralize, and adjusts spacing" do
      msg = %Content.Message.StoppedTrain{destination: :braintree, stops_away: 1}

      assert Content.Message.to_string(msg) ==
               [
                 {"Braintree  Stopped", 6},
                 {"Braintree   1 stop", 6},
                 {"Braintree     away", 6}
               ]
    end
  end

  @prediction %Predictions.Prediction{
    route_id: "Red",
    direction_id: 1,
    boarding_status: "Stopped 1 stop away"
  }

  describe "new" do
    test "parses 'Stopped n stations away' message" do
      prediction = %{@prediction | boarding_status: "Stopped 5 stops away"}

      assert %Content.Message.StoppedTrain{destination: :alewife, stops_away: 5} =
               Content.Message.StoppedTrain.new(prediction, false, nil)
    end

    test "parses singular stop" do
      prediction = %{@prediction | boarding_status: "Stopped 1 stop away"}

      assert %Content.Message.StoppedTrain{destination: :alewife, stops_away: 1} =
               Content.Message.StoppedTrain.new(prediction, false, nil)
    end

    test "parses 2-digit stops" do
      prediction = %{@prediction | boarding_status: "Stopped 10 stops away"}

      assert %Content.Message.StoppedTrain{destination: :alewife, stops_away: 10} =
               Content.Message.StoppedTrain.new(prediction, false, nil)
    end
  end
end
