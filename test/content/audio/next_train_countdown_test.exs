defmodule Content.Audio.NextTrainCountdownTest do
  use ExUnit.Case, async: true

  describe "Content.Audio.to_params protocol" do
    test "Next train to Ashmont" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :ashmont,
        route_id: "Mattapan",
        verb: :arrives,
        minutes: 5,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {:canned, {"90", ["4016", "503", "5005"], :audio}}
    end

    test "Next train to Mattapan" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :mattapan,
        route_id: "Mattapan",
        verb: :arrives,
        minutes: 5,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {:canned, {"90", ["4100", "503", "5005"], :audio}}
    end

    test "Next train to Bowdoin" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :bowdoin,
        route_id: "Blue",
        verb: :arrives,
        minutes: 5,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {:canned, {"90", ["4055", "503", "5005"], :audio}}
    end

    test "Next train to Wonderland" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :wonderland,
        route_id: "Blue",
        verb: :arrives,
        minutes: 5,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {:canned, {"90", ["4044", "503", "5005"], :audio}}
    end

    test "Next train to Forest Hills" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :forest_hills,
        route_id: "Orange",
        verb: :arrives,
        minutes: 5,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {:canned, {"90", ["4043", "503", "5005"], :audio}}
    end

    test "Next train to Oak Grove" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :oak_grove,
        route_id: "Orange",
        verb: :arrives,
        minutes: 5,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {:canned, {"90", ["4022", "503", "5005"], :audio}}
    end

    test "Next train to Alewife" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        route_id: "Red",
        verb: :arrives,
        minutes: 5,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {:canned, {"90", ["4000", "503", "5005"], :audio}}
    end

    test "Next train to Alewife arrives in one minute" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        route_id: "Red",
        verb: :arrives,
        minutes: 1,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {:canned, {"141", ["4000", "503"], :audio}}
    end

    test "Next train to Alewife on the Ashmont platform" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        route_id: "Red",
        verb: :arrives,
        minutes: 5,
        track_number: nil,
        platform: :ashmont
      }

      assert Content.Audio.to_params(audio) ==
               {:canned, {"98", ["4000", "503", "5005", "4016"], :audio}}
    end

    test "Next train to Alewife on the Ashmont platform arrives in one minute" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        route_id: "Red",
        verb: :arrives,
        minutes: 1,
        track_number: nil,
        platform: :ashmont
      }

      assert Content.Audio.to_params(audio) == {:canned, {"142", ["4000", "4016", "503"], :audio}}
    end

    test "Next train to Alewife on the Braintree platform" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        route_id: "Red",
        verb: :arrives,
        minutes: 5,
        track_number: nil,
        platform: :braintree
      }

      assert Content.Audio.to_params(audio) ==
               {:canned, {"98", ["4000", "503", "5005", "4021"], :audio}}
    end

    test "Next train to Alewife platform TBD soon (JFK/UMass Mezzanine only)" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        route_id: "Red",
        verb: :arrives,
        minutes: 9,
        track_number: nil,
        platform: :braintree,
        station_code: "RJFK",
        zone: "m"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"117",
                 [
                   "501",
                   "21000",
                   "507",
                   "21000",
                   "4000",
                   "21000",
                   "503",
                   "21000",
                   "504",
                   "21000",
                   "5009",
                   "21000",
                   "505",
                   "21000",
                   "849"
                 ], :audio}}
    end

    test "Next train to Alewife platform TBD when train closer (JFK/UMass Mezzanine only)" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        route_id: "Red",
        verb: :arrives,
        minutes: 10,
        track_number: nil,
        platform: :braintree,
        station_code: "RJFK",
        zone: "m"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"117",
                 [
                   "501",
                   "21000",
                   "507",
                   "21000",
                   "4000",
                   "21000",
                   "503",
                   "21000",
                   "504",
                   "21000",
                   "5010",
                   "21000",
                   "505",
                   "21000",
                   "857"
                 ], :audio}}
    end

    test "Next train to Braintree" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :braintree,
        route_id: "Red",
        verb: :arrives,
        minutes: 5,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {:canned, {"90", ["4021", "503", "5005"], :audio}}
    end

    test "can read larger numbers" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :wonderland,
        route_id: "Blue",
        verb: :arrives,
        minutes: 50,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {:canned, {"90", ["4044", "503", "5050"], :audio}}
    end

    test "Next D train in 5 minutes" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :riverside,
        route_id: "Green-D",
        verb: :arrives,
        minutes: 5,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"117",
                 [
                   "501",
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
      audio = %Content.Audio.NextTrainCountdown{
        destination: :boston_college,
        route_id: "Green-B",
        verb: :arrives,
        minutes: 1,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"117",
                 [
                   "501",
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
      audio = %Content.Audio.NextTrainCountdown{
        destination: :park_street,
        route_id: "Green-B",
        verb: :arrives,
        minutes: 5,
        track_number: nil,
        platform: nil
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"117",
                 [
                   "501",
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

    test "Next train to Braintree on track 1" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :braintree,
        route_id: "Red",
        verb: :departs,
        minutes: 5,
        track_number: 1,
        platform: nil
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"117",
                 [
                   "501",
                   "21000",
                   "507",
                   "21000",
                   "4021",
                   "21000",
                   "502",
                   "21000",
                   "504",
                   "21000",
                   "5005",
                   "21000",
                   "505",
                   "21000",
                   "541"
                 ], :audio}}
    end

    test "Next train to Braintree in 1 minute on track 1" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :braintree,
        route_id: "Red",
        verb: :departs,
        minutes: 1,
        track_number: 1,
        platform: nil
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"117",
                 [
                   "501",
                   "21000",
                   "507",
                   "21000",
                   "4021",
                   "21000",
                   "502",
                   "21000",
                   "504",
                   "21000",
                   "5001",
                   "21000",
                   "532",
                   "21000",
                   "541"
                 ], :audio}}
    end
  end
end
