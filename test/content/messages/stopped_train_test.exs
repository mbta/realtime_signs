defmodule Content.Message.StoppedTrainTest do
  use ExUnit.Case, async: true

  describe "to_string/1" do
    test "returns BRD string if stopped 0 stops away" do
      msg = %Content.Message.StoppedTrain{headsign: "Ashmont", stops_away: 0}
      assert Content.Message.to_string(msg) == "Ashmont        BRD"
    end

    test "returns tuple of stopped away pages otherwise" do
      msg = %Content.Message.StoppedTrain{headsign: "Braintree", stops_away: 2}

      assert Content.Message.to_string(msg) == {
               [
                 "Braintree  Stopped",
                 "Braintree  2 stops",
                 "Braintree     away"
               ],
               3
             }
    end

    test "if only 1 stop away, doesn't pluralize, and adjusts spacing" do
      msg = %Content.Message.StoppedTrain{headsign: "Braintree", stops_away: 1}

      assert Content.Message.to_string(msg) == {
               [
                 "Braintree  Stopped",
                 "Braintree   1 stop",
                 "Braintree     away"
               ],
               3
             }
    end
  end

  @boarding_prediction %Predictions.Prediction{
    route_id: "Red",
    direction_id: 1,
    boarding_status: "Boarding"
  }

  @prediction %Predictions.Prediction{
    route_id: "Red",
    direction_id: 1,
    boarding_status: "Boarding"
  }

  describe "from_prediction/1" do
    test "handles 'boarding' message" do
      assert Content.Message.StoppedTrain.from_prediction(@boarding_prediction) ==
               %Content.Message.StoppedTrain{
                 headsign: "Alewife",
                 stops_away: 0
               }
    end

    test "handles 'Stopped at station' message" do
      assert Content.Message.StoppedTrain.from_prediction(@prediction) ==
               %Content.Message.StoppedTrain{
                 headsign: "Alewife",
                 stops_away: 0
               }
    end

    test "parses 'Stopped n stations away' message" do
      prediction = %{@prediction | boarding_status: "Stopped 5 stops away"}

      assert Content.Message.StoppedTrain.from_prediction(prediction) ==
               %Content.Message.StoppedTrain{
                 headsign: "Alewife",
                 stops_away: 5
               }
    end

    test "parses singular stop" do
      prediction = %{@prediction | boarding_status: "Stopped 1 stop away"}

      assert Content.Message.StoppedTrain.from_prediction(prediction) ==
               %Content.Message.StoppedTrain{
                 headsign: "Alewife",
                 stops_away: 1
               }
    end

    test "parses 2-digit stops" do
      prediction = %{@prediction | boarding_status: "Stopped 10 stops away"}

      assert Content.Message.StoppedTrain.from_prediction(prediction) ==
               %Content.Message.StoppedTrain{
                 headsign: "Alewife",
                 stops_away: 10
               }
    end

    test "handles unknown final stop_id" do
      prediction = %{@prediction | direction_id: 0, destination_stop_id: "123"}

      assert Content.Message.StoppedTrain.from_prediction(prediction) ==
               %Content.Message.StoppedTrain{
                 headsign: "",
                 stops_away: 0
               }
    end
  end
end
