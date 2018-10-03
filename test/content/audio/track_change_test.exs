defmodule Content.Audio.TrackChangeTest do
  use ExUnit.Case, async: true

  describe "to_params/1" do
    test "correctly changes tracks" do
      audio = %Content.Audio.TrackChange{
        destination: :boston_college,
        route_id: "Green-B",
        track: 1
      }

      assert Content.Audio.to_params(audio) ==
               {"109", ["540", "501", "536", "507", "4202", "544", "541"], :audio}
    end
  end

  describe "from_message/1" do
    test "when a prediction is on the wrong track and is boarding, makes the announcement" do
      prediction = %Content.Message.Predictions{
        stop_id: "70199",
        minutes: :boarding,
        route_id: "Green-D",
        headsign: :reservoir
      }

      assert Content.Audio.TrackChange.from_message(prediction) == %Content.Audio.TrackChange{
               destination: :reservoir,
               route_id: "Green-D",
               track: 1
             }
    end

    test "when a prediction is on the wrong track and is not boarding, does not make the announcement" do
      prediction = %Content.Message.Predictions{
        stop_id: "70199",
        minutes: :arriving,
        route_id: "Green-D",
        headsign: :reservoir
      }

      assert Content.Audio.TrackChange.from_message(prediction) == nil
    end

    test "when a prediction is on the right track, is nil" do
      prediction = %Content.Message.Predictions{
        stop_id: "70199",
        minutes: :boarding,
        route_id: "Green-C",
        headsign: :cleveland_circle
      }

      assert Content.Audio.TrackChange.from_message(prediction) == nil
    end
  end
end
