defmodule Content.Message.StoppedTrainTest do
  use ExUnit.Case, async: true

  describe "to_string/1" do
    test "returns tuple of stopped away pages otherwise" do
      msg = %Content.Message.StoppedTrain{destination: :braintree, stops_away: 2}

      assert Content.Message.to_string(msg) ==
               [
                 {"Braintree  Stopped", 4},
                 {"Braintree  2 stops", 4},
                 {"Braintree     away", 4}
               ]
    end

    test "if only 1 stop away, doesn't pluralize, and adjusts spacing" do
      msg = %Content.Message.StoppedTrain{destination: :braintree, stops_away: 1}

      assert Content.Message.to_string(msg) ==
               [
                 {"Braintree  Stopped", 4},
                 {"Braintree   1 stop", 4},
                 {"Braintree     away", 4}
               ]
    end
  end

  @prediction %Predictions.Prediction{
    route_id: "Red",
    direction_id: 1,
    boarding_status: "Stopped 1 stop away"
  }

  describe "from_prediction/1" do
    test "parses 'Stopped n stations away' message" do
      prediction = %{@prediction | boarding_status: "Stopped 5 stops away"}

      assert Content.Message.StoppedTrain.from_prediction(prediction) ==
               %Content.Message.StoppedTrain{
                 destination: :alewife,
                 stops_away: 5
               }
    end

    test "parses singular stop" do
      prediction = %{@prediction | boarding_status: "Stopped 1 stop away"}

      assert Content.Message.StoppedTrain.from_prediction(prediction) ==
               %Content.Message.StoppedTrain{
                 destination: :alewife,
                 stops_away: 1
               }
    end

    test "parses 2-digit stops" do
      prediction = %{@prediction | boarding_status: "Stopped 10 stops away"}

      assert Content.Message.StoppedTrain.from_prediction(prediction) ==
               %Content.Message.StoppedTrain{
                 destination: :alewife,
                 stops_away: 10
               }
    end

    test "handles unknown final stop_id" do
      prediction = %{@prediction | route_id: "Fake Route", destination_stop_id: "123"}

      assert is_nil(Content.Message.StoppedTrain.from_prediction(prediction))
    end
  end
end
