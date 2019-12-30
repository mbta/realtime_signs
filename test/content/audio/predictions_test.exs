defmodule Content.Audio.PredictionsTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Content.Message
  alias Content.Audio
  alias Signs.Utilities.SourceConfig
  import Content.Audio.Predictions

  @src %SourceConfig{
    stop_id: "70196",
    direction_id: 0,
    headway_direction_name: "Heath St",
    platform: nil,
    terminal?: false,
    announce_arriving?: false,
    announce_boarding?: true
  }

  describe "from_sign_content/3" do
    test "returns a TrackChange audio when Green-B boarding other side at Park St" do
      src = %{@src | stop_id: "70197", direction_id: 0, headway_direction_name: "Boston Col"}

      predictions = %Message.Predictions{
        destination: :boston_college,
        minutes: :boarding,
        route_id: "Green-B",
        stop_id: "70197"
      }

      assert %Audio.TrackChange{
               destination: :boston_college,
               route_id: "Green-B",
               track: 1
             } = from_sign_content({src, predictions}, :top, false)
    end

    test "returns a TrackChange audio when Green-E boarding other side at Park St" do
      src = %{@src | stop_id: "70196", direction_id: 0, headway_direction_name: "Heath St"}

      predictions = %Message.Predictions{
        destination: :heath_street,
        minutes: :boarding,
        route_id: "Green-E",
        stop_id: "70196"
      }

      assert %Audio.TrackChange{
               destination: :heath_street,
               route_id: "Green-E",
               track: 2
             } = from_sign_content({src, predictions}, :top, false)
    end

    test "returns a NextTrainCountdown if it's the wrong track but somehow not boarding" do
      src = %{@src | stop_id: "70196", direction_id: 0, headway_direction_name: "Heath St"}

      predictions = %Message.Predictions{
        destination: :heath_street,
        minutes: 2,
        route_id: "Green-E",
        stop_id: "70196"
      }

      assert %Audio.NextTrainCountdown{
               destination: :heath_street,
               verb: :arrives,
               minutes: 2
             } = from_sign_content({src, predictions}, :top, false)
    end

    test "returns an Approaching audio if predictions say it's approaching on the top line" do
      src = %{
        @src
        | stop_id: "70085",
          direction_id: 0,
          headway_direction_name: "Southbound",
          platform: :ashmont
      }

      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: :approaching,
        route_id: "Red",
        stop_id: "70085",
        trip_id: "trip1",
        new_cars?: false
      }

      assert %Audio.Approaching{
               destination: :ashmont,
               trip_id: "trip1",
               platform: :ashmont,
               route_id: "Red",
               new_cars?: false
             } = from_sign_content({src, predictions}, :top, false)
    end

    test "returns an Approaching audio with new cars flag set" do
      src = %{
        @src
        | stop_id: "70085",
          direction_id: 0,
          headway_direction_name: "Southbound",
          platform: :ashmont
      }

      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: :approaching,
        route_id: "Red",
        stop_id: "70085",
        trip_id: "trip1",
        new_cars?: true
      }

      assert %Audio.Approaching{
               destination: :ashmont,
               trip_id: "trip1",
               platform: :ashmont,
               route_id: "Red",
               new_cars?: true
             } = from_sign_content({src, predictions}, :top, false)
    end

    test "returns a NextTrainCountdown audio for 'minutes: :approaching' and top line, but light rail" do
      src = %{
        @src
        | stop_id: "70155",
          direction_id: 0,
          headway_direction_name: "Westbound"
      }

      predictions = %Message.Predictions{
        destination: :riverside,
        minutes: :approaching,
        route_id: "Green-D",
        stop_id: "70155",
        trip_id: "trip1"
      }

      assert %Audio.NextTrainCountdown{
               destination: :riverside,
               minutes: 1
             } = from_sign_content({src, predictions}, :top, false)
    end

    test "returns a NextTrainCountdown audio if predictions say it's approaching on the bottom line" do
      src = %{@src | stop_id: "70065", direction_id: 0, headway_direction_name: "Southbound"}

      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: :approaching,
        route_id: "Red",
        stop_id: "70065"
      }

      assert %Audio.NextTrainCountdown{
               destination: :ashmont,
               minutes: 1,
               verb: :arrives,
               track_number: nil,
               platform: nil
             } = from_sign_content({src, predictions}, :bottom, false)
    end

    test "returns a TrainIsBoarding audio if predictions say it's boarding" do
      src = %{@src | stop_id: "70065", direction_id: 0, headway_direction_name: "Southbound"}

      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: :boarding,
        route_id: "Red",
        stop_id: "70065",
        trip_id: "trip1"
      }

      assert %Audio.TrainIsBoarding{
               destination: :ashmont,
               trip_id: "trip1",
               route_id: "Red",
               track_number: nil
             } = from_sign_content({src, predictions}, :top, false)
    end

    test "returns a TrainIsArriving audio if predictions say it's arriving" do
      src = %{
        @src
        | stop_id: "70085",
          direction_id: 0,
          headway_direction_name: "Southbound",
          platform: :ashmont
      }

      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: :arriving,
        route_id: "Red",
        stop_id: "70085",
        trip_id: "trip1"
      }

      assert %Audio.TrainIsArriving{
               destination: :ashmont,
               trip_id: "trip1",
               platform: :ashmont,
               route_id: "Red"
             } = from_sign_content({src, predictions}, :top, false)
    end

    test "returns a NextTrainCountdown arriving audio if prediction is minutes away and non-terminal source" do
      src = %{
        @src
        | stop_id: "70065",
          direction_id: 0,
          headway_direction_name: "Southbound",
          terminal?: false
      }

      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: 1,
        route_id: "Red",
        stop_id: "70065"
      }

      assert %Audio.NextTrainCountdown{destination: :ashmont, verb: :arrives, minutes: 1} =
               from_sign_content({src, predictions}, :top, false)
    end

    test "returns a NextTrainCountdown departing audio if prediction is minutes away and terminal source" do
      src = %{
        @src
        | stop_id: "70061",
          direction_id: 0,
          headway_direction_name: "Southbound",
          terminal?: true
      }

      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: 1,
        route_id: "Red",
        stop_id: "70061"
      }

      assert %Audio.NextTrainCountdown{destination: :ashmont, verb: :departs, minutes: 1} =
               from_sign_content({src, predictions}, :top, false)
    end

    test "returns a NextTrainCountdown with appropriate platform" do
      src = %{
        @src
        | stop_id: "70096",
          direction_id: 1,
          headway_direction_name: "Alewife",
          platform: :ashmont
      }

      predictions = %Message.Predictions{
        destination: :alewife,
        minutes: 2,
        route_id: "Red",
        stop_id: "70096"
      }

      assert %Audio.NextTrainCountdown{
               destination: :alewife,
               verb: :arrives,
               minutes: 2,
               platform: :ashmont
             } = from_sign_content({src, predictions}, :top, false)
    end

    test "returns a NextTrainCountdown with 30 mins if predictions is :max_time" do
      src = %{
        @src
        | stop_id: "70065",
          direction_id: 0,
          headway_direction_name: "Southbound",
          terminal?: false
      }

      predictions = %Message.Predictions{
        destination: :ashmont,
        minutes: :max_time,
        route_id: "Red",
        stop_id: "70065"
      }

      assert %Audio.NextTrainCountdown{destination: :ashmont, verb: :arrives, minutes: 20} =
               from_sign_content({src, predictions}, :top, false)
    end
  end
end
