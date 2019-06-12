defmodule Content.Message.PredictionsTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "non_terminal/3" do
    test "logs a warning when we cant find a headsign" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 0,
        direction_id: 1,
        route_id: "NON-ROUTE",
        stopped?: false,
        stops_away: 1,
        destination_stop_id: "70261"
      }

      log =
        capture_log([level: :warn], fn ->
          Content.Message.Predictions.non_terminal(prediction)
        end)

      assert log =~ "Could not find headsign for prediction"
    end

    test "puts ARR on the sign when train is 0 seconds away, but not boarding" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 0,
        direction_id: 1,
        route_id: "Mattapan",
        stopped?: false,
        stops_away: 1,
        destination_stop_id: "70261"
      }

      msg = Content.Message.Predictions.non_terminal(prediction)

      assert Content.Message.to_string(msg) == "Ashmont        ARR"
    end

    test "puts BRD on the sign when train is zero stops away" do
      prediction = %Predictions.Prediction{
        direction_id: 1,
        route_id: "Mattapan",
        destination_stop_id: "70261",
        stopped?: false,
        stops_away: 0,
        boarding_status: "Boarding"
      }

      msg = Content.Message.Predictions.non_terminal(prediction)

      assert Content.Message.to_string(msg) == "Ashmont        BRD"
    end

    test "puts arriving on the sign when train is 0-30 seconds away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 30,
        direction_id: 0,
        route_id: "Mattapan",
        stopped?: false,
        stops_away: 1,
        destination_stop_id: "70275"
      }

      msg = Content.Message.Predictions.non_terminal(prediction)

      assert Content.Message.to_string(msg) == "Mattapan       ARR"
    end

    test "puts minutes on the sign when train is 31 seconds away (approaching)" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 31,
        direction_id: 0,
        route_id: "Mattapan",
        stopped?: false,
        stops_away: 1,
        destination_stop_id: "70275"
      }

      msg = Content.Message.Predictions.non_terminal(prediction)

      assert Content.Message.to_string(msg) == "Mattapan     1 min"
    end

    test "puts minutes on the sign when train is 61 seconds away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 61,
        direction_id: 0,
        route_id: "Mattapan",
        stopped?: false,
        stops_away: 1,
        destination_stop_id: "70275"
      }

      msg = Content.Message.Predictions.non_terminal(prediction)

      assert Content.Message.to_string(msg) == "Mattapan     1 min"
    end

    test "Says 20+ min when train is 20 or more minutes away" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 45 * 60,
        direction_id: 0,
        route_id: "Mattapan",
        stopped?: false,
        stops_away: 10,
        destination_stop_id: "70275"
      }

      msg = Content.Message.Predictions.non_terminal(prediction)

      assert Content.Message.to_string(msg) == "Mattapan   20+ min"
    end

    test "can use a shorter line length" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 550,
        route_id: "Mattapan",
        direction_id: 0,
        stopped?: false,
        stops_away: 3,
        destination_stop_id: "70275"
      }

      msg = Content.Message.Predictions.non_terminal(prediction, 15)
      assert Content.Message.to_string(msg) == "Mattapan  9 min"
    end

    test "1 minute (singular) prediction" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 65,
        direction_id: 1,
        route_id: "Mattapan",
        stopped?: false,
        stops_away: 1,
        destination_stop_id: "70261"
      }

      msg = Content.Message.Predictions.non_terminal(prediction)

      assert Content.Message.to_string(msg) == "Ashmont      1 min"
    end

    test "multiple minutes prediction" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 125,
        direction_id: 1,
        route_id: "Mattapan",
        stopped?: false,
        stops_away: 2,
        destination_stop_id: "70261"
      }

      msg = Content.Message.Predictions.non_terminal(prediction)

      assert Content.Message.to_string(msg) == "Ashmont      2 min"
    end

    test "Still shows predictions for negative arrivals" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: -5,
        route_id: "Mattapan",
        direction_id: 1,
        stopped?: false,
        stops_away: 1,
        destination_stop_id: "70261"
      }

      msg = Content.Message.Predictions.non_terminal(prediction)

      assert Content.Message.to_string(msg) == "Ashmont        ARR"
    end

    test "Shows BRD for negative arrival times if vehicle is STOPPED_AT" do
      prediction = %Predictions.Prediction{
        route_id: "Mattapan",
        direction_id: 1,
        destination_stop_id: "70261",
        stopped?: false,
        stops_away: 0,
        boarding_status: "Boarding"
      }

      msg = Content.Message.Predictions.non_terminal(prediction)

      assert Content.Message.to_string(msg) == "Ashmont        BRD"
    end

    test "Rounds to the nearest minute" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 91,
        route_id: "Mattapan",
        direction_id: 1,
        stopped?: false,
        stops_away: 2,
        destination_stop_id: "70261"
      }

      msg = Content.Message.Predictions.non_terminal(prediction)

      assert Content.Message.to_string(msg) == "Ashmont      2 min"
    end

    test "Includes the prediction's trip_id" do
      prediction = %Predictions.Prediction{
        seconds_until_arrival: 91,
        route_id: "Mattapan",
        direction_id: 1,
        stopped?: false,
        stops_away: 2,
        destination_stop_id: "70261",
        trip_id: "trip1"
      }

      msg = Content.Message.Predictions.non_terminal(prediction)

      assert msg.trip_id == "trip1"
    end
  end

  describe "terminal/3" do
    test "logs a warning when we cant find a headsign, even if it should be boarding" do
      prediction = %Predictions.Prediction{
        seconds_until_departure: 0,
        direction_id: 1,
        route_id: "NON-ROUTE",
        destination_stop_id: "70261",
        stopped?: false,
        stops_away: 0,
        boarding_status: "Boarding"
      }

      log =
        capture_log([level: :warn], fn ->
          Content.Message.Predictions.terminal(prediction)
        end)

      assert log =~ "Could not find headsign for prediction"
    end

    test "logs a warning when we cant find a headsign" do
      prediction = %Predictions.Prediction{
        seconds_until_departure: 0,
        direction_id: 1,
        route_id: "NON-ROUTE",
        stopped?: false,
        stops_away: 1,
        destination_stop_id: "70261"
      }

      log =
        capture_log([level: :warn], fn ->
          Content.Message.Predictions.terminal(prediction)
        end)

      assert log =~ "Could not find headsign for prediction"
    end

    test "puts boarding on the sign when train is supposed to be boarding according to rtr" do
      prediction = %Predictions.Prediction{
        seconds_until_departure: 75,
        direction_id: 1,
        route_id: "Mattapan",
        destination_stop_id: "70261",
        stopped?: false,
        stops_away: 0,
        boarding_status: "Stopped at station"
      }

      msg = Content.Message.Predictions.terminal(prediction)

      assert Content.Message.to_string(msg) == "Ashmont        BRD"
    end

    test "does not put boarding on the sign too early when train is stopped at terminal" do
      prediction = %Predictions.Prediction{
        seconds_until_departure: 95,
        direction_id: 1,
        route_id: "Mattapan",
        destination_stop_id: "70261",
        stopped?: false,
        stops_away: 0,
        boarding_status: "Stopped at station"
      }

      msg = Content.Message.Predictions.terminal(prediction)

      assert Content.Message.to_string(msg) == "Ashmont      1 min"
    end

    test "offsets the prediction by 60 seconds" do
      prediction = %Predictions.Prediction{
        seconds_until_departure: 209,
        direction_id: 1,
        route_id: "Mattapan",
        destination_stop_id: "70261",
        stopped?: false,
        stops_away: 0,
        boarding_status: "Stopped at station"
      }

      msg = Content.Message.Predictions.terminal(prediction)

      assert Content.Message.to_string(msg) == "Ashmont      2 min"
    end

    test "puts 1 min on the sign when train is not boarding, but is predicted to depart in less than a minute when offset" do
      prediction = %Predictions.Prediction{
        seconds_until_departure: 70,
        direction_id: 1,
        route_id: "Mattapan",
        stopped?: false,
        stops_away: 1,
        destination_stop_id: "70261"
      }

      msg = Content.Message.Predictions.terminal(prediction)

      assert Content.Message.to_string(msg) == "Ashmont      1 min"
    end

    test "pages track information when available" do
      prediction = %Predictions.Prediction{
        stop_id: "Forest Hills-02",
        seconds_until_departure: 180,
        direction_id: 1,
        route_id: "Orange",
        stopped?: false,
        stops_away: 0
      }

      msg = Content.Message.Predictions.terminal(prediction)

      assert Content.Message.to_string(msg) == [
               {"Oak Grove    2 min", 3},
               {"Oak Grove    Trk 2", 3}
             ]
    end

    test "Includes the prediction's trip_id" do
      prediction = %Predictions.Prediction{
        seconds_until_departure: 91,
        route_id: "Mattapan",
        direction_id: 1,
        stopped?: false,
        stops_away: 2,
        destination_stop_id: "70261",
        trip_id: "trip1"
      }

      msg = Content.Message.Predictions.terminal(prediction)

      assert msg.trip_id == "trip1"
    end
  end
end
