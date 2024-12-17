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

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"115", spaced(["501", "4016", "864", "503", "504", "5005", "505"]), :audio}}
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

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"115", spaced(["501", "4000", "864", "503", "504", "5001", "532"]), :audio}}
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
               {:canned,
                {"121",
                 spaced(["501", "4000", "864", "503", "504", "5005", "505", "851", "4016", "529"]),
                 :audio}}
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

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"121",
                 spaced(["501", "4000", "864", "851", "4016", "529", "503", "504", "5001", "532"]),
                 :audio}}
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
               {:canned,
                {"121",
                 spaced(["501", "4000", "864", "503", "504", "5005", "505", "851", "4021", "529"]),
                 :audio}}
    end

    test "Next train to Alewife platform TBD soon (JFK/UMass Mezzanine only)" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        route_id: "Red",
        verb: :arrives,
        minutes: 9,
        track_number: nil,
        platform: :braintree,
        special_sign: :jfk_mezzanine
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"117", spaced(["501", "4000", "864", "503", "504", "5009", "505", "849"]),
                 :audio}}
    end

    test "Next train to Alewife platform TBD when train closer (JFK/UMass Mezzanine only)" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        route_id: "Red",
        verb: :arrives,
        minutes: 10,
        track_number: nil,
        platform: :braintree,
        special_sign: :jfk_mezzanine
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"117", spaced(["501", "4000", "864", "503", "504", "5010", "505", "857"]),
                 :audio}}
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
                {"117", spaced(["501", "538", "507", "4084", "503", "504", "5005", "505"]),
                 :audio}}
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
                {"117", spaced(["501", "536", "507", "4202", "503", "504", "5001", "532"]),
                 :audio}}
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
                {"117", spaced(["501", "536", "507", "4007", "503", "504", "5005", "505"]),
                 :audio}}
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
                {"117", spaced(["501", "4021", "864", "502", "504", "5005", "505", "541"]),
                 :audio}}
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
                {"117", spaced(["501", "4021", "864", "502", "504", "5001", "532", "541"]),
                 :audio}}
    end
  end

  defp spaced(list), do: Enum.intersperse(list, "21000")
end
