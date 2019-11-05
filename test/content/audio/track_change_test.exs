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
               {:sign_content,
                {"109", ["540", "501", "536", "507", "4202", "544", "541"], :audio_visual}}
    end

    test "correctly changes tracks for c/e" do
      audio = %Content.Audio.TrackChange{
        destination: :heath_st,
        route_id: "Green-E",
        track: 1
      }

      assert Content.Audio.to_params(audio) ==
               {:sign_content,
                {"109", ["540", "501", "539", "507", "4204", "544", "541"], :audio_visual}}
    end

    test "Logs error and returns nil if southbound destination" do
      audio = %Content.Audio.TrackChange{
        destination: :southbound,
        route_id: "Green-E",
        track: 1
      }

      log =
        capture_log([level: :error], fn ->
          assert Content.Audio.to_params(audio) == nil
        end)

      assert log =~ "TrackChange audio for southbound"
    end
  end
end
