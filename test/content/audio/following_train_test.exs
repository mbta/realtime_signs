defmodule Content.Audio.FollowingTrainTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "Content.Audio.to_params protocol" do
    test "Following train to Ashmont" do
      audio = %Content.Audio.FollowingTrain{
        destination: :ashmont,
        route_id: "Mattapan",
        verb: :arrives,
        minutes: 5
      }

      assert Content.Audio.to_params(audio) == {:canned, {"160", ["4016", "503", "5005"], :audio}}
    end

    test "when its a non terminal it uses arrives" do
      message = %Content.Message.Predictions{
        destination: :ashmont,
        route_id: "Mattapan",
        minutes: 5
      }

      audio =
        Content.Audio.FollowingTrain.from_predictions_message(
          {%{
             terminal?: false,
             platform: nil
           }, message}
        )

      assert audio == [
               %Content.Audio.FollowingTrain{
                 destination: :ashmont,
                 route_id: "Mattapan",
                 minutes: 5,
                 verb: :arrives
               }
             ]
    end

    test "when its a terminal it uses departs" do
      message = %Content.Message.Predictions{
        destination: :ashmont,
        route_id: "Mattapan",
        minutes: 5
      }

      audio =
        Content.Audio.FollowingTrain.from_predictions_message(
          {%{
             terminal?: true,
             platform: nil
           }, message}
        )

      assert audio == [
               %Content.Audio.FollowingTrain{
                 destination: :ashmont,
                 route_id: "Mattapan",
                 minutes: 5,
                 verb: :departs
               }
             ]
    end

    test "when its 1 minute, uses the right singular announcement" do
      audio = %Content.Audio.FollowingTrain{
        destination: :ashmont,
        route_id: "Mattpan",
        verb: :arrives,
        minutes: 1
      }

      assert Content.Audio.to_params(audio) == {:canned, {"159", ["4016", "503"], :audio}}
    end

    test "Next D train in 5 minutes" do
      audio = %Content.Audio.FollowingTrain{
        destination: :riverside,
        route_id: "Green-D",
        verb: :arrives,
        minutes: 5
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"117",
                 [
                   "667",
                   "21000",
                   "538",
                   "21000",
                   "507",
                   "21000",
                   "4084",
                   "21000",
                   "503",
                   "21000",
                   "504",
                   "21000",
                   "5005",
                   "21000",
                   "505"
                 ], :audio}}
    end

    test "Next B train in 1 minute" do
      audio = %Content.Audio.FollowingTrain{
        destination: :boston_college,
        route_id: "Green-B",
        verb: :arrives,
        minutes: 1
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"117",
                 [
                   "667",
                   "21000",
                   "536",
                   "21000",
                   "507",
                   "21000",
                   "4202",
                   "21000",
                   "503",
                   "21000",
                   "504",
                   "21000",
                   "5001",
                   "21000",
                   "532"
                 ], :audio}}
    end

    test "Eastbound Green Line trains also get branch letters" do
      audio = %Content.Audio.FollowingTrain{
        destination: :park_street,
        route_id: "Green-B",
        verb: :arrives,
        minutes: 5
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"117",
                 [
                   "667",
                   "21000",
                   "536",
                   "21000",
                   "507",
                   "21000",
                   "4007",
                   "21000",
                   "503",
                   "21000",
                   "504",
                   "21000",
                   "5005",
                   "21000",
                   "505"
                 ], :audio}}
    end

    test "returns ad_hoc audio when the destination is 'southbound'" do
      audio = %Content.Audio.FollowingTrain{
        destination: :southbound,
        route_id: "Red",
        verb: :arrives,
        minutes: 3
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc, {"The following Southbound Red Line train arrives in 3 minutes", :audio}}
    end

    test "Returns ad_hoc audio for valid destinations" do
      audio = %Content.Audio.FollowingTrain{
        destination: :eastbound,
        route_id: "Green-D",
        verb: :arrives,
        minutes: 3
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc, {"The following Eastbound train arrives in 3 minutes", :audio}}
    end

    test "Handles unknown destination gracefully" do
      audio = %Content.Audio.FollowingTrain{
        destination: :unknown,
        route_id: "Foo",
        verb: :arrives,
        minutes: 3
      }

      log =
        capture_log([level: :error], fn ->
          assert Content.Audio.to_params(audio) == nil
        end)

      assert log =~ "unknown destination"
    end
  end
end
