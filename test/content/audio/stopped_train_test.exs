defmodule Content.Audio.StoppedTrainTest do
  use ExUnit.Case, async: true

  describe "to_params/1" do
    test "Serializes correctly" do
      audio = %Content.Audio.StoppedTrain{destination: :alewife, route_id: "Red", stops_away: 2}

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"115",
                 [
                   "501",
                   "21000",
                   "507",
                   "21000",
                   "4000",
                   "21000",
                   "533",
                   "21000",
                   "641",
                   "21000",
                   "5002",
                   "21000",
                   "534"
                 ], :audio}}
    end

    test "Uses singular 'stop' if 1 stop away" do
      audio = %Content.Audio.StoppedTrain{destination: :alewife, route_id: "Red", stops_away: 1}

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"115",
                 [
                   "501",
                   "21000",
                   "507",
                   "21000",
                   "4000",
                   "21000",
                   "533",
                   "21000",
                   "641",
                   "21000",
                   "5001",
                   "21000",
                   "535"
                 ], :audio}}
    end
  end

  describe "from_message/1" do
    test "Converts a stopped train message with known headsign" do
      msg = %Content.Message.StoppedTrain{
        destination: :forest_hills,
        prediction: %Predictions.Prediction{route_id: "Orange"},
        stops_away: 1
      }

      assert Content.Audio.StoppedTrain.from_message(msg) ==
               [
                 %Content.Audio.StoppedTrain{
                   destination: :forest_hills,
                   route_id: "Orange",
                   stops_away: 1
                 }
               ]
    end

    test "Returns nil for irrelevant message" do
      msg = %Content.Message.Empty{}
      assert Content.Audio.StoppedTrain.from_message(msg) == []
    end

    test "when the trian is stopped 0 stops away, does not announce that it is stopped 0 stops away" do
      msg = %Content.Message.StoppedTrain{destination: :forest_hills, stops_away: 0}

      assert Content.Audio.StoppedTrain.from_message(msg) == []
    end
  end
end
