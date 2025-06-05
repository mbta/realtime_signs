defmodule Content.Audio.TrackChangeTest do
  use ExUnit.Case, async: true

  describe "to_params/1" do
    test "correctly changes berths from b to d" do
      audio = %Content.Audio.TrackChange{
        destination: :boston_college,
        route_id: "Green-B",
        berth: "70198"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"119",
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
                   "851",
                   "21000",
                   "538",
                   "21000",
                   "529"
                 ], :audio_visual}}
    end

    test "correctly changes berths from c to e" do
      audio = %Content.Audio.TrackChange{
        destination: :cleveland_circle,
        route_id: "Green-C",
        berth: "70199"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"119",
                 [
                   "540",
                   "21000",
                   "501",
                   "21000",
                   "537",
                   "21000",
                   "507",
                   "21000",
                   "4203",
                   "21000",
                   "544",
                   "21000",
                   "851",
                   "21000",
                   "539",
                   "21000",
                   "529"
                 ], :audio_visual}}
    end

    test "correctly changes berths from d to b (reservoir)" do
      audio = %Content.Audio.TrackChange{
        destination: :reservoir,
        route_id: "Green-D",
        berth: "70196"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"119",
                 [
                   "540",
                   "21000",
                   "501",
                   "21000",
                   "538",
                   "21000",
                   "507",
                   "21000",
                   "4076",
                   "21000",
                   "544",
                   "21000",
                   "851",
                   "21000",
                   "536",
                   "21000",
                   "529"
                 ], :audio_visual}}
    end

    test "correctly changes berths from d to b (riverside)" do
      audio = %Content.Audio.TrackChange{
        destination: :riverside,
        route_id: "Green-D",
        berth: "70196"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"119",
                 [
                   "540",
                   "21000",
                   "501",
                   "21000",
                   "538",
                   "21000",
                   "507",
                   "21000",
                   "4084",
                   "21000",
                   "544",
                   "21000",
                   "851",
                   "21000",
                   "536",
                   "21000",
                   "529"
                 ], :audio_visual}}
    end

    test "correctly changes berths from e to c" do
      audio = %Content.Audio.TrackChange{
        destination: :heath_street,
        route_id: "Green-E",
        berth: "70197"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"119",
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
                   "851",
                   "21000",
                   "537",
                   "21000",
                   "529"
                 ], :audio_visual}}
    end

    test "correctly announces Kenmore B track changes to the D platform" do
      audio = %Content.Audio.TrackChange{
        destination: :kenmore,
        route_id: "Green-B",
        berth: "70198"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"119",
                 [
                   "540",
                   "21000",
                   "501",
                   "21000",
                   "536",
                   "21000",
                   "507",
                   "21000",
                   "4070",
                   "21000",
                   "544",
                   "21000",
                   "851",
                   "21000",
                   "538",
                   "21000",
                   "529"
                 ], :audio_visual}}
    end

    test "correctly announces Kenmore C track changes to the E platform" do
      audio = %Content.Audio.TrackChange{
        destination: :kenmore,
        route_id: "Green-C",
        berth: "70199"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"119",
                 [
                   "540",
                   "21000",
                   "501",
                   "21000",
                   "537",
                   "21000",
                   "507",
                   "21000",
                   "4070",
                   "21000",
                   "544",
                   "21000",
                   "851",
                   "21000",
                   "539",
                   "21000",
                   "529"
                 ], :audio_visual}}
    end

    test "correctly announces Kenmore D track changes to the B platform" do
      audio = %Content.Audio.TrackChange{
        destination: :kenmore,
        route_id: "Green-D",
        berth: "70196"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"119",
                 [
                   "540",
                   "21000",
                   "501",
                   "21000",
                   "538",
                   "21000",
                   "507",
                   "21000",
                   "4070",
                   "21000",
                   "544",
                   "21000",
                   "851",
                   "21000",
                   "536",
                   "21000",
                   "529"
                 ], :audio_visual}}
    end

    test "correctly announces Kenmore E track changes to the C platform" do
      audio = %Content.Audio.TrackChange{
        destination: :kenmore,
        route_id: "Green-E",
        berth: "70197"
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"119",
                 [
                   "540",
                   "21000",
                   "501",
                   "21000",
                   "539",
                   "21000",
                   "507",
                   "21000",
                   "4070",
                   "21000",
                   "544",
                   "21000",
                   "851",
                   "21000",
                   "537",
                   "21000",
                   "529"
                 ], :audio_visual}}
    end
  end
end
