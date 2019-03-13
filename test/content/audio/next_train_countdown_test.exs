defmodule Content.Audio.NextTrainCountdownTest do
  use ExUnit.Case, async: true

  describe "Content.Audio.to_params protocol" do
    test "Next train to Ashmont" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :ashmont,
        verb: :arrives,
        minutes: 5,
        stop_id: "70264",
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4016", "503", "5005"], :audio}
    end

    test "Next train to Mattapan" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :mattapan,
        verb: :arrives,
        minutes: 5,
        stop_id: "70263",
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4100", "503", "5005"], :audio}
    end

    test "Next train to Bowdoin" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :bowdoin,
        verb: :arrives,
        minutes: 5,
        stop_id: "70057",
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4055", "503", "5005"], :audio}
    end

    test "Next train to Wonderland" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :wonderland,
        verb: :arrives,
        minutes: 5,
        stop_id: "70058",
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4044", "503", "5005"], :audio}
    end

    test "Next train to Forest Hills" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :forest_hills,
        verb: :arrives,
        minutes: 5,
        stop_id: "70022",
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4043", "503", "5005"], :audio}
    end

    test "Next train to Oak Grove" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :oak_grove,
        verb: :arrives,
        minutes: 5,
        stop_id: "70023",
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4022", "503", "5005"], :audio}
    end

    test "Next train to Alewife" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        verb: :arrives,
        minutes: 5,
        stop_id: "70064",
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4000", "503", "5005"], :audio}
    end

    test "Next train to Alewife arrives in one minute" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        verb: :arrives,
        minutes: 1,
        stop_id: "70064",
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"141", ["4000", "503"], :audio}
    end

    test "Next train to Alewife on the Ashmont platform" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        verb: :arrives,
        minutes: 5,
        stop_id: "70086",
        platform: :ashmont
      }

      assert Content.Audio.to_params(audio) == {"99", ["4000", "4016", "503", "5005"], :audio}
    end

    test "Next train to Alewife on the Ashmont platform arrives in one minute" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        verb: :arrives,
        minutes: 1,
        stop_id: "70086",
        platform: :ashmont
      }

      assert Content.Audio.to_params(audio) == {"142", ["4000", "4016", "503"], :audio}
    end

    test "Next train to Alewife on the Braintree platform" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :alewife,
        verb: :arrives,
        minutes: 5,
        stop_id: "70096",
        platform: :braintree
      }

      assert Content.Audio.to_params(audio) == {"99", ["4000", "4021", "503", "5005"], :audio}
    end

    test "Next train to Braintree" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :braintree,
        verb: :arrives,
        minutes: 5,
        stop_id: "70063",
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4021", "503", "5005"], :audio}
    end

    test "Uses audio for 30 minutes when train is more than 30 minutes away" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :wonderland,
        verb: :arrives,
        minutes: 50,
        stop_id: "70048",
        platform: nil
      }

      assert Content.Audio.to_params(audio) == {"90", ["4044", "503", "5030"], :audio}
    end

    test "Next train to Braintree on track 1" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :braintree,
        verb: :departs,
        minutes: 5,
        stop_id: "Alewife-01",
        platform: nil
      }

      assert Content.Audio.to_params(audio) ==
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
                ], :audio_visual}
    end

    test "Next train to Braintree in 1 minute on track 1" do
      audio = %Content.Audio.NextTrainCountdown{
        destination: :braintree,
        verb: :departs,
        minutes: 1,
        stop_id: "Alewife-01",
        platform: nil
      }

      assert Content.Audio.to_params(audio) ==
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
                  "505",
                  "21000",
                  "541"
                ], :audio_visual}
    end
  end
end
