defmodule Content.Audio.TrackChangeTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "to_params/1" do
    test "correctly changes berths from b to c" do
      audio = %Content.Audio.TrackChange{
        destination: :boston_college,
        route_id: "Green-B",
        berth: "70197"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"105",
                 [
                   "540",
                   "21000",
                   "813"
                 ], :audio_visual}}
    end

    test "correctly changes berths from c to b" do
      audio = %Content.Audio.TrackChange{
        destination: :cleveland_circle,
        route_id: "Green-C",
        berth: "70196"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"105",
                 [
                   "540",
                   "21000",
                   "814"
                 ], :audio_visual}}
    end

    test "correctly changes berths from d to e (reservoir)" do
      audio = %Content.Audio.TrackChange{
        destination: :reservoir,
        route_id: "Green-D",
        berth: "70199"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"105",
                 [
                   "540",
                   "21000",
                   "815"
                 ], :audio_visual}}
    end

    test "correctly changes berths from d to e (riverside)" do
      audio = %Content.Audio.TrackChange{
        destination: :riverside,
        route_id: "Green-D",
        berth: "70199"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"105",
                 [
                   "540",
                   "21000",
                   "818"
                 ], :audio_visual}}
    end

    test "correctly changes berths from e to d" do
      audio = %Content.Audio.TrackChange{
        destination: :heath_street,
        route_id: "Green-E",
        berth: "70198"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"105",
                 [
                   "540",
                   "21000",
                   "816"
                 ], :audio_visual}}
    end

    test "correctly announces Kenmore B track changes to the C platform" do
      audio = %Content.Audio.TrackChange{
        destination: :kenmore,
        route_id: "Green-B",
        berth: "70197"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"105",
                 [
                   "540",
                   "21000",
                   "820"
                 ], :audio_visual}}
    end

    test "correctly announces Kenmore C track changes to the B platform" do
      audio = %Content.Audio.TrackChange{
        destination: :kenmore,
        route_id: "Green-C",
        berth: "70196"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"105",
                 [
                   "540",
                   "21000",
                   "823"
                 ], :audio_visual}}
    end

    test "correctly announces Kenmore D track changes to the E platform" do
      audio = %Content.Audio.TrackChange{
        destination: :kenmore,
        route_id: "Green-D",
        berth: "70199"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"105",
                 [
                   "540",
                   "21000",
                   "822"
                 ], :audio_visual}}
    end

    test "correctly announces Kenmore E track changes to the D platform" do
      audio = %Content.Audio.TrackChange{
        destination: :kenmore,
        route_id: "Green-E",
        berth: "70198"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"105",
                 [
                   "540",
                   "21000",
                   "821"
                 ], :audio_visual}}
    end

    test "Handles unknown destination gracefully" do
      audio = %Content.Audio.TrackChange{
        destination: :unknown,
        route_id: "Green-E",
        berth: "00000"
      }

      log =
        capture_log([level: :error], fn ->
          assert Content.Audio.to_params(audio) == nil
        end)

      assert log =~ "unknown route, berth, destination"
    end
  end
end
