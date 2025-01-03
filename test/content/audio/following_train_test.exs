defmodule Content.Audio.FollowingTrainTest do
  use ExUnit.Case, async: true

  describe "Content.Audio.to_params protocol" do
    test "Following train to Ashmont" do
      audio = %Content.Audio.FollowingTrain{
        destination: :ashmont,
        route_id: "Mattapan",
        verb: :arrives,
        minutes: 5
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"115", spaced(["667", "4016", "864", "503", "504", "5005", "505"]), :audio}}
    end

    test "when its a non terminal it uses arrives" do
      message = %Content.Message.Predictions{
        destination: :ashmont,
        prediction: %Predictions.Prediction{route_id: "Mattapan"},
        minutes: 5,
        approximate?: false,
        terminal?: false,
        special_sign: nil
      }

      audio = Content.Audio.FollowingTrain.from_predictions_message(message)

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
        prediction: %Predictions.Prediction{route_id: "Mattapan"},
        minutes: 5,
        approximate?: false,
        terminal?: true,
        special_sign: nil
      }

      audio = Content.Audio.FollowingTrain.from_predictions_message(message)

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

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"115", spaced(["667", "4016", "864", "503", "504", "5001", "532"]), :audio}}
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
                {"117", spaced(["667", "538", "507", "4084", "503", "504", "5005", "505"]),
                 :audio}}
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
                {"117", spaced(["667", "536", "507", "4202", "503", "504", "5001", "532"]),
                 :audio}}
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
                {"117", spaced(["667", "536", "507", "4007", "503", "504", "5005", "505"]),
                 :audio}}
    end
  end

  defp spaced(list), do: Enum.intersperse(list, "21000")
end
