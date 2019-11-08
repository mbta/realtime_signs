defmodule Content.Audio.TrackChangeTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "to_params/1" do
    test "correctly changes tracks for b/d" do
      audio = %Content.Audio.TrackChange{
        destination: :boston_college,
        route_id: "Green-B",
        track: 1
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"109",
                 [
                   "540",
                   "21000",
                   "501",
                   "21000",
                   "536",
                   "21000",
                   "507",
                   "21000",
                   "4202",
                   "21000",
                   "544",
                   "21000",
                   "541"
                 ], :audio_visual}}
    end

    test "correctly changes tracks for c/e" do
      audio = %Content.Audio.TrackChange{
        destination: :heath_street,
        route_id: "Green-E",
        track: 1
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"109",
                 [
                   "540",
                   "21000",
                   "501",
                   "21000",
                   "539",
                   "21000",
                   "507",
                   "21000",
                   "4204",
                   "21000",
                   "544",
                   "21000",
                   "541"
                 ], :audio_visual}}
    end

    test "Handles unknown destination gracefully" do
      audio = %Content.Audio.TrackChange{
        destination: :unknown,
        route_id: "Green-E",
        track: 1
      }

      log =
        capture_log([level: :error], fn ->
          assert Content.Audio.to_params(audio) == nil
        end)

      assert log =~ "unknown destination"
    end
  end
end
