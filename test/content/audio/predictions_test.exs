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

  describe "from_sign_content/2" do
    test "returns a TrackChange audio when Green-B boarding other side at Park St" do
      src = %{@src | stop_id: "70197", direction_id: 0, headway_direction_name: "Boston Col"}

      predictions = %Message.Predictions{
        headsign: "Boston Col",
        minutes: :boarding,
        route_id: "Green-B",
        stop_id: "70197"
      }

      assert %Audio.TrackChange{
               destination: :boston_college,
               route_id: "Green-B",
               track: 1
             } = from_sign_content({src, predictions}, :top)
    end

    test "returns a TrackChange audio when Green-E boarding other side at Park St" do
      src = %{@src | stop_id: "70196", direction_id: 0, headway_direction_name: "Heath St"}

      predictions = %Message.Predictions{
        headsign: "Heath St",
        minutes: :boarding,
        route_id: "Green-E",
        stop_id: "70196"
      }

      assert %Audio.TrackChange{
               destination: :heath_st,
               route_id: "Green-E",
               track: 2
             } = from_sign_content({src, predictions}, :top)
    end

    test "returns a NextTrainCountdown if it's the wrong track but somehow not boarding" do
      src = %{@src | stop_id: "70196", direction_id: 0, headway_direction_name: "Heath St"}

      predictions = %Message.Predictions{
        headsign: "Heath St",
        minutes: 2,
        route_id: "Green-E",
        stop_id: "70196"
      }

      assert %Audio.NextTrainCountdown{
               destination: :heath_st,
               verb: :arrives,
               minutes: 2
             } = from_sign_content({src, predictions}, :top)
    end

    test "returns an Approaching audio if predictions say it's approaching on the top line" do
      src = %{@src | stop_id: "70065", direction_id: 0, headway_direction_name: "Southbound"}

      predictions = %Message.Predictions{
        headsign: "Ashmont",
        minutes: :approaching,
        route_id: "Red",
        stop_id: "70065"
      }

      assert %Audio.Approaching{destination: :ashmont} =
               from_sign_content({src, predictions}, :top)
    end

    test "returns a NextTrainCountdown audio if predictions say it's approaching on the bottom line" do
      src = %{@src | stop_id: "70065", direction_id: 0, headway_direction_name: "Southbound"}

      predictions = %Message.Predictions{
        headsign: "Ashmont",
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
             } = from_sign_content({src, predictions}, :bottom)
    end

    test "returns a TrainIsBoarding audio if predictions say it's boarding" do
      src = %{@src | stop_id: "70065", direction_id: 0, headway_direction_name: "Southbound"}

      predictions = %Message.Predictions{
        headsign: "Ashmont",
        minutes: :boarding,
        route_id: "Red",
        stop_id: "70065"
      }

      assert %Audio.TrainIsBoarding{destination: :ashmont, route_id: "Red", track_number: nil} =
               from_sign_content({src, predictions}, :top)
    end

    test "returns a TrainIsArriving audio if predictions say it's arriving" do
      src = %{@src | stop_id: "70065", direction_id: 0, headway_direction_name: "Southbound"}

      predictions = %Message.Predictions{
        headsign: "Ashmont",
        minutes: :arriving,
        route_id: "Red",
        stop_id: "70065"
      }

      assert %Audio.TrainIsArriving{destination: :ashmont} =
               from_sign_content({src, predictions}, :top)
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
        headsign: "Ashmont",
        minutes: 1,
        route_id: "Red",
        stop_id: "70065"
      }

      assert %Audio.NextTrainCountdown{destination: :ashmont, verb: :arrives, minutes: 1} =
               from_sign_content({src, predictions}, :top)
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
        headsign: "Ashmont",
        minutes: 1,
        route_id: "Red",
        stop_id: "70061"
      }

      assert %Audio.NextTrainCountdown{destination: :ashmont, verb: :departs, minutes: 1} =
               from_sign_content({src, predictions}, :top)
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
        headsign: "Alewife",
        minutes: 2,
        route_id: "Red",
        stop_id: "70096"
      }

      assert %Audio.NextTrainCountdown{
               destination: :alewife,
               verb: :arrives,
               minutes: 2,
               platform: :ashmont
             } = from_sign_content({src, predictions}, :top)
    end

    test "returns a NextTrainCountdown with 30 mins if predictions is :thirty_plus" do
      src = %{
        @src
        | stop_id: "70065",
          direction_id: 0,
          headway_direction_name: "Southbound",
          terminal?: false
      }

      predictions = %Message.Predictions{
        headsign: "Ashmont",
        minutes: :thirty_plus,
        route_id: "Red",
        stop_id: "70065"
      }

      assert %Audio.NextTrainCountdown{destination: :ashmont, verb: :arrives, minutes: 30} =
               from_sign_content({src, predictions}, :top)
    end

    test "returns nil and logs warning if invalid headsign" do
      predictions = %Message.Predictions{
        headsign: "Mars",
        minutes: 1,
        route_id: "Red",
        stop_id: "70061"
      }

      log =
        capture_log([level: :warn], fn ->
          assert from_sign_content({@src, predictions}, :top) == nil
        end)

      assert log =~ "unknown headsign"
    end
  end
end
