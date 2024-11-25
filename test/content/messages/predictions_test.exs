defmodule Content.Message.PredictionsTest do
  use ExUnit.Case, async: true

  describe "non-terminal new/3" do
    test "puts ARR on the sign when train is 0 seconds away, but not boarding" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 0,
        direction_id: 1,
        route_id: "Mattapan",
        destination_stop_id: "70261"
      }

      msg = Content.Message.Predictions.new(prediction, false, nil)

      assert Content.Message.to_string(msg) == "Ashmont        ARR"
    end

    test "puts BRD on the sign when train is zero stops away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 0,
        direction_id: 1,
        route_id: "Mattapan",
        destination_stop_id: "70261",
        stopped_at_predicted_stop?: true,
        boarding_status: "Boarding"
      }

      msg = Content.Message.Predictions.new(prediction, false, nil)

      assert Content.Message.to_string(msg) == "Ashmont        BRD"
    end

    test "puts arriving on the sign when train is 0-30 seconds away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 30,
        direction_id: 0,
        route_id: "Mattapan",
        destination_stop_id: "70275"
      }

      msg = Content.Message.Predictions.new(prediction, false, nil)

      assert Content.Message.to_string(msg) == "Mattapan       ARR"
    end

    test "puts minutes on the sign when train is 31 seconds away (approaching)" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 31,
        direction_id: 0,
        route_id: "Mattapan",
        destination_stop_id: "70275"
      }

      msg = Content.Message.Predictions.new(prediction, false, nil)

      assert Content.Message.to_string(msg) == "Mattapan     1 min"
    end

    test "puts minutes on the sign when train is 61 seconds away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 61,
        direction_id: 0,
        route_id: "Mattapan",
        destination_stop_id: "70275"
      }

      msg = Content.Message.Predictions.new(prediction, false, nil)

      assert Content.Message.to_string(msg) == "Mattapan     1 min"
    end

    test "shows approximate minutes for longer turnaround predictions" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 25 * 60,
        arrival_certainty: 360,
        direction_id: 0,
        route_id: "Mattapan",
        destination_stop_id: "70275"
      }

      msg = Content.Message.Predictions.new(prediction, false, nil)

      assert Content.Message.to_string(msg) == "Mattapan   20+ min"
    end

    test "1 minute (singular) prediction" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 65,
        direction_id: 1,
        route_id: "Mattapan",
        destination_stop_id: "70261"
      }

      msg = Content.Message.Predictions.new(prediction, false, nil)

      assert Content.Message.to_string(msg) == "Ashmont      1 min"
    end

    test "multiple minutes prediction" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 125,
        direction_id: 1,
        route_id: "Mattapan",
        destination_stop_id: "70261"
      }

      msg = Content.Message.Predictions.new(prediction, false, nil)

      assert Content.Message.to_string(msg) == "Ashmont      2 min"
    end

    test "Still shows predictions for negative arrivals" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: -5,
        route_id: "Mattapan",
        direction_id: 1,
        destination_stop_id: "70261"
      }

      msg = Content.Message.Predictions.new(prediction, false, nil)

      assert Content.Message.to_string(msg) == "Ashmont        ARR"
    end

    test "Shows BRD for negative arrival times if vehicle is STOPPED_AT" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: -5,
        route_id: "Mattapan",
        direction_id: 1,
        destination_stop_id: "70261",
        stopped_at_predicted_stop?: true,
        boarding_status: "Boarding"
      }

      msg = Content.Message.Predictions.new(prediction, false, nil)

      assert Content.Message.to_string(msg) == "Ashmont        BRD"
    end

    test "Rounds to the nearest minute" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 91,
        route_id: "Mattapan",
        direction_id: 1,
        destination_stop_id: "70261"
      }

      msg = Content.Message.Predictions.new(prediction, false, nil)

      assert Content.Message.to_string(msg) == "Ashmont      2 min"
    end

    test "Includes Ashmont platform when northbound to JFK/UMass Mezzanine" do
      prediction = %Predictions.Prediction{
        stop_id: "70086",
        seconds_until_arrival: 300,
        direction_id: 1,
        route_id: "Red"
      }

      msg = Content.Message.Predictions.new(prediction, false, :jfk_mezzanine)

      assert Content.Message.to_string(msg) == [
               {"Alewife (A)  5 min", 6},
               {"Alewife (Ashmont plat)", 6}
             ]
    end

    test "Includes Braintree platform when northbound to JFK/UMass Mezzanine" do
      prediction = %Predictions.Prediction{
        stop_id: "70096",
        seconds_until_arrival: 300,
        direction_id: 1,
        route_id: "Red"
      }

      msg = Content.Message.Predictions.new(prediction, false, :jfk_mezzanine)

      assert Content.Message.to_string(msg) == [
               {"Alewife (B)  5 min", 6},
               {"Alewife (Braintree plat)", 6}
             ]
    end

    test "Platform TBD when northbound to JFK/UMass Mezzanine and over 5 min" do
      prediction = %Predictions.Prediction{
        stop_id: "70096",
        seconds_until_arrival: 360,
        direction_id: 1,
        route_id: "Red"
      }

      msg = Content.Message.Predictions.new(prediction, false, :jfk_mezzanine)

      assert Content.Message.to_string(msg) == [
               {"Alewife      6 min", 6},
               {"Alewife (Platform TBD)", 6}
             ]
    end
  end

  describe "terminal new/3" do
    test "puts boarding on the sign when train is supposed to be boarding according to rtr" do
      prediction = %Predictions.Prediction{
        seconds_until_departure: 15,
        direction_id: 1,
        route_id: "Mattapan",
        destination_stop_id: "70261",
        stopped_at_predicted_stop?: true,
        boarding_status: "Stopped at station"
      }

      msg = Content.Message.Predictions.new(prediction, true, nil)

      assert Content.Message.to_string(msg) == "Ashmont        BRD"
    end

    test "does not put boarding on the sign too early when train is stopped at terminal" do
      prediction = %Predictions.Prediction{
        seconds_until_departure: 35,
        direction_id: 1,
        route_id: "Mattapan",
        destination_stop_id: "70261",
        stopped_at_predicted_stop?: true,
        boarding_status: "Stopped at station"
      }

      msg = Content.Message.Predictions.new(prediction, true, nil)

      assert Content.Message.to_string(msg) == "Ashmont      1 min"
    end

    test "puts 1 min on the sign when train is not boarding, but is predicted to depart in less than a minute when offset" do
      prediction = %Predictions.Prediction{
        seconds_until_departure: 70,
        direction_id: 1,
        route_id: "Mattapan",
        destination_stop_id: "70261"
      }

      msg = Content.Message.Predictions.new(prediction, true, nil)

      assert Content.Message.to_string(msg) == "Ashmont      1 min"
    end

    test "pages track information when available" do
      prediction = %Predictions.Prediction{
        stop_id: "Forest Hills-02",
        seconds_until_departure: 120,
        direction_id: 1,
        route_id: "Orange",
        stopped_at_predicted_stop?: true
      }

      msg = Content.Message.Predictions.new(prediction, true, nil)

      assert Content.Message.to_string(msg) == [
               {"Oak Grove    2 min", 6},
               {"Oak Grove    Trk 2", 6}
             ]
    end
  end
end
