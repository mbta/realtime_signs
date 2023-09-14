defmodule Content.Audio.PredictionsTest do
  use ExUnit.Case, async: true

  alias Content.Message
  alias Content.Audio
  import Content.Audio.Predictions

  describe "from_sign_content/3" do
    test "returns a TrackChange audio when Green-B boarding at C berth at Park St" do
      predictions = %Message.Predictions{
        destination: :boston_college,
        minutes: :boarding,
        route_id: "Green-B",
        stop_id: "70197"
      }

      assert [
               %Audio.TrackChange{
                 destination: :boston_college,
                 route_id: "Green-B",
                 berth: "70197"
               }
             ] = from_sign_content(predictions, :top, false)
    end

    test "returns a TrackChange audio when Green-E boarding at D berth at Park St" do
      predictions = %Message.Predictions{
        destination: :heath_street,
        minutes: :boarding,
        route_id: "Green-E",
        stop_id: "70198"
      }

      assert [
               %Audio.TrackChange{
                 destination: :heath_street,
                 route_id: "Green-E",
                 berth: "70198"
               }
             ] = from_sign_content(predictions, :top, false)
    end

    test "returns a NextTrainCountdown if it's the wrong track but somehow not boarding" do
      predictions = %Message.Predictions{
        destination: :heath_street,
        minutes: 2,
        route_id: "Green-E",
        stop_id: "70196"
      }

      assert [
               %Audio.NextTrainCountdown{
                 destination: :heath_street,
                 verb: :arrives,
                 minutes: 2
               }
             ] = from_sign_content(predictions, :top, false)
    end

    test "returns an Approaching audio if predictions say it's approaching on the top line" do
      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: :approaching,
        route_id: "Red",
        stop_id: "70085",
        trip_id: "trip1",
        platform: :ashmont,
        new_cars?: false
      }

      assert [
               %Audio.Approaching{
                 destination: :ashmont,
                 trip_id: "trip1",
                 platform: :ashmont,
                 route_id: "Red",
                 new_cars?: false
               }
             ] = from_sign_content(predictions, :top, false)
    end

    test "returns an Approaching audio with new cars flag set" do
      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: :approaching,
        route_id: "Red",
        stop_id: "70085",
        trip_id: "trip1",
        platform: :ashmont,
        new_cars?: true
      }

      assert [
               %Audio.Approaching{
                 destination: :ashmont,
                 trip_id: "trip1",
                 platform: :ashmont,
                 route_id: "Red",
                 new_cars?: true
               }
             ] = from_sign_content(predictions, :top, false)
    end

    test "returns a NextTrainCountdown audio for 'minutes: :approaching' and top line, but light rail" do
      predictions = %Message.Predictions{
        destination: :riverside,
        minutes: :approaching,
        route_id: "Green-D",
        stop_id: "70155",
        trip_id: "trip1"
      }

      assert [%Audio.NextTrainCountdown{destination: :riverside, minutes: 1}] =
               from_sign_content(predictions, :top, false)
    end

    test "returns a NextTrainCountdown audio if predictions say it's approaching on the bottom line" do
      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: :approaching,
        route_id: "Red",
        stop_id: "70065"
      }

      assert [
               %Audio.NextTrainCountdown{
                 destination: :ashmont,
                 minutes: 1,
                 verb: :arrives,
                 track_number: nil,
                 platform: nil
               }
             ] = from_sign_content(predictions, :bottom, false)
    end

    test "returns a TrainIsBoarding audio if predictions say it's boarding" do
      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: :boarding,
        route_id: "Red",
        stop_id: "70065",
        trip_id: "trip1"
      }

      assert [
               %Audio.TrainIsBoarding{
                 destination: :ashmont,
                 trip_id: "trip1",
                 route_id: "Red",
                 track_number: nil
               }
             ] = from_sign_content(predictions, :top, false)
    end

    test "returns a TrainIsArriving audio if predictions say it's arriving" do
      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: :arriving,
        route_id: "Red",
        stop_id: "70085",
        trip_id: "trip1",
        platform: :ashmont
      }

      assert [
               %Audio.TrainIsArriving{
                 destination: :ashmont,
                 trip_id: "trip1",
                 platform: :ashmont,
                 route_id: "Red"
               }
             ] = from_sign_content(predictions, :top, false)
    end

    test "returns a NextTrainCountdown arriving audio if prediction is minutes away and non-terminal source" do
      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: 1,
        route_id: "Red",
        stop_id: "70065"
      }

      assert [%Audio.NextTrainCountdown{destination: :ashmont, verb: :arrives, minutes: 1}] =
               from_sign_content(predictions, :top, false)
    end

    test "returns a NextTrainCountdown departing audio if prediction is minutes away and terminal source" do
      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: 1,
        route_id: "Red",
        stop_id: "70061",
        terminal?: true
      }

      assert [%Audio.NextTrainCountdown{destination: :ashmont, verb: :departs, minutes: 1}] =
               from_sign_content(predictions, :top, false)
    end

    test "returns a NextTrainCountdown with appropriate platform" do
      predictions = %Message.Predictions{
        destination: :alewife,
        minutes: 2,
        route_id: "Red",
        stop_id: "70096",
        platform: :ashmont
      }

      assert [
               %Audio.NextTrainCountdown{
                 destination: :alewife,
                 verb: :arrives,
                 minutes: 2,
                 platform: :ashmont
               }
             ] = from_sign_content(predictions, :top, false)
    end

    test "returns a NextTrainCountdown with approximate minutes" do
      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: 20,
        approximate?: true,
        route_id: "Red",
        stop_id: "70065"
      }

      assert [%Audio.NextTrainCountdown{destination: :ashmont, verb: :arrives, minutes: 20}] =
               from_sign_content(predictions, :top, false)
    end
  end
end
