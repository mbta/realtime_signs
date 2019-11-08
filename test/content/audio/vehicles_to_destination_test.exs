defmodule Content.Audio.VehiclesToDestinationTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  import Content.Audio.VehiclesToDestination

  describe "to_params/1" do
    test "Buses to Chelsea in English" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :chelsea,
        language: :english,
        next_trip_mins: 7,
        later_trip_mins: 10
      }

      assert Content.Audio.to_params(audio) == {:canned, {"133", ["5507", "5510"], :audio}}
    end

    test "Buses to Chelsea in Spanish" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :chelsea,
        language: :spanish,
        next_trip_mins: 7,
        later_trip_mins: 10
      }

      assert Content.Audio.to_params(audio) == {:canned, {"150", ["37007", "37010"], :audio}}
    end

    test "Buses to South Station in English" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :south_station,
        language: :english,
        next_trip_mins: 7,
        later_trip_mins: 10
      }

      assert Content.Audio.to_params(audio) == {:canned, {"134", ["5507", "5510"], :audio}}
    end

    test "Buses to South Station in Spanish" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :south_station,
        language: :spanish,
        next_trip_mins: 7,
        later_trip_mins: 10
      }

      assert Content.Audio.to_params(audio) == {:canned, {"151", ["37007", "37010"], :audio}}
    end

    test "Buses to South Station in Spanish, headway out of range" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :south_station,
        language: :spanish,
        next_trip_mins: 7,
        later_trip_mins: 21
      }

      log =
        capture_log([level: :warn], fn ->
          assert Content.Audio.to_params(audio) == nil
        end)

      assert log =~ "no_audio_for_headway_range"
    end

    test "Buses to South Station in Spanish, headway range of more than 10 minutes but still uses canned message" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :south_station,
        language: :spanish,
        next_trip_mins: 7,
        later_trip_mins: 18
      }

      assert Content.Audio.to_params(audio) == {:canned, {"151", ["37007", "37018"], :audio}}
    end

    test "returns a robo-voice message for headways with a last departure" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :lechmere,
        language: :english,
        next_trip_mins: 5,
        later_trip_mins: 7,
        previous_departure_mins: 5
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc,
                {"Trains to Lechmere every 5 to 7 minutes.  Previous departure 5 minutes ago.",
                 :audio}}
    end

    test "returns a robo-voice message for headways with a single number range" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :lechmere,
        language: :english,
        next_trip_mins: 7,
        later_trip_mins: 7
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc, {"Trains to Lechmere every 7 minutes.", :audio}}
    end

    test "singularizes the minutes when the last departure was one minute ago" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :lechmere,
        language: :english,
        next_trip_mins: 5,
        later_trip_mins: 7,
        previous_departure_mins: 1
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc,
                {"Trains to Lechmere every 5 to 7 minutes.  Previous departure 1 minute ago.",
                 :audio}}
    end

    test "returns a robo-voice message for a headway range that is too big" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :lechmere,
        language: :english,
        next_trip_mins: 5,
        later_trip_mins: 20,
        previous_departure_mins: 5
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc,
                {"Trains to Lechmere up to every 20 minutes.  Previous departure 5 minutes ago.",
                 :audio}}
    end

    test "returns a robo-voice message for a headway that is too big with no last departure" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :lechmere,
        language: :english,
        next_trip_mins: 5,
        later_trip_mins: 20
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc, {"Trains to Lechmere up to every 20 minutes.", :audio}}
    end

    test "returns correct audio for cardinal direction, rather than terminal, headways" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :southbound,
        language: :english,
        next_trip_mins: 5,
        later_trip_mins: 7,
        previous_departure_mins: 3
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc,
                {"Southbound trains every 5 to 7 minutes.  Previous departure 3 minutes ago.",
                 :audio}}
    end
  end

  describe "from_headway_message/2" do
    @msg %Content.Message.Headways.Bottom{range: {5, 7}}

    test "returns an audio message from a headway message to chelsea" do
      assert {
               %Content.Audio.VehiclesToDestination{language: :english, destination: :chelsea},
               %Content.Audio.VehiclesToDestination{language: :spanish, destination: :chelsea}
             } = from_headway_message(%Content.Message.Headways.Top{headsign: "Chelsea"}, @msg)
    end

    test "returns an audio message from a headway message to red/orange/blue/green line terminals" do
      # green line
      assert %Content.Audio.VehiclesToDestination{
               language: :english,
               destination: :lechmere
             } = from_headway_message(%Content.Message.Headways.Top{headsign: "Lechmere"}, @msg)

      assert %Content.Audio.VehiclesToDestination{
               language: :english,
               destination: :government_center
             } = from_headway_message(%Content.Message.Headways.Top{headsign: "Govt Ctr"}, @msg)

      assert %Content.Audio.VehiclesToDestination{
               language: :english,
               destination: :north_station
             } =
               from_headway_message(
                 %Content.Message.Headways.Top{headsign: "North Station"},
                 @msg
               )

      assert %Content.Audio.VehiclesToDestination{language: :english, destination: :park_street} =
               from_headway_message(%Content.Message.Headways.Top{headsign: "Park Street"}, @msg)

      assert %Content.Audio.VehiclesToDestination{
               language: :english,
               destination: :heath_street
             } = from_headway_message(%Content.Message.Headways.Top{headsign: "Heath St"}, @msg)

      assert %Content.Audio.VehiclesToDestination{
               language: :english,
               destination: :riverside
             } = from_headway_message(%Content.Message.Headways.Top{headsign: "Riverside"}, @msg)

      assert %Content.Audio.VehiclesToDestination{
               language: :english,
               destination: :boston_college
             } =
               from_headway_message(
                 %Content.Message.Headways.Top{headsign: "Boston College"},
                 @msg
               )

      assert %Content.Audio.VehiclesToDestination{
               language: :english,
               destination: :cleveland_circle
             } =
               from_headway_message(
                 %Content.Message.Headways.Top{headsign: "Cleveland Circle"},
                 @msg
               )

      # blue line
      assert %Content.Audio.VehiclesToDestination{
               language: :english,
               destination: :bowdoin
             } = from_headway_message(%Content.Message.Headways.Top{headsign: "Bowdoin"}, @msg)

      assert %Content.Audio.VehiclesToDestination{language: :english, destination: :wonderland} =
               from_headway_message(%Content.Message.Headways.Top{headsign: "Wonderland"}, @msg)

      # orange line
      assert %Content.Audio.VehiclesToDestination{
               language: :english,
               destination: :forest_hills
             } = from_headway_message(%Content.Message.Headways.Top{headsign: "Frst Hills"}, @msg)

      assert %Content.Audio.VehiclesToDestination{language: :english, destination: :oak_grove} =
               from_headway_message(%Content.Message.Headways.Top{headsign: "Oak Grove"}, @msg)

      # red line
      assert %Content.Audio.VehiclesToDestination{language: :english, destination: :alewife} =
               from_headway_message(%Content.Message.Headways.Top{headsign: "Alewife"}, @msg)

      assert %Content.Audio.VehiclesToDestination{language: :english, destination: :ashmont} =
               from_headway_message(%Content.Message.Headways.Top{headsign: "Ashmont"}, @msg)

      assert %Content.Audio.VehiclesToDestination{language: :english, destination: :braintree} =
               from_headway_message(%Content.Message.Headways.Top{headsign: "Braintree"}, @msg)
    end

    test "returns an audio message from a headway message to south station" do
      assert {
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :south_station
               },
               %Content.Audio.VehiclesToDestination{
                 language: :spanish,
                 destination: :south_station
               }
             } =
               from_headway_message(
                 %Content.Message.Headways.Top{headsign: "South Station"},
                 @msg
               )
    end

    test "returns nils for an unknown destination" do
      log =
        capture_log([level: :warn], fn ->
          assert from_headway_message(%Content.Message.Headways.Top{headsign: "Unknown"}, @msg) ==
                   nil
        end)

      assert log =~ "message_to_audio_error"
    end

    test "returns nils when range is all nil, but doesn't warn" do
      msg = %{@msg | range: {nil, nil}}

      log =
        capture_log([level: :warn], fn ->
          assert from_headway_message(%Content.Message.Headways.Top{headsign: "Chelsea"}, msg) ==
                   nil
        end)

      refute log =~ "from_headway_message"
    end

    test "returns nil when range is unexpected" do
      msg = %{@msg | range: {:a, :b, :c}}

      assert from_headway_message(%Content.Message.Headways.Top{headsign: "Chelsea"}, msg) == nil
    end

    test "returns a padded range when one value is missing or values are the same" do
      msg1 = %{@msg | range: {10, nil}}
      msg2 = %{@msg | range: {nil, 10}}
      msg3 = %{@msg | range: {10, 10}}

      Enum.each([msg1, msg2, msg3], fn msg ->
        assert {
                 %Content.Audio.VehiclesToDestination{
                   language: :english,
                   next_trip_mins: 10,
                   later_trip_mins: 12
                 },
                 %Content.Audio.VehiclesToDestination{
                   language: :spanish,
                   next_trip_mins: 10,
                   later_trip_mins: 12
                 }
               } = from_headway_message(%Content.Message.Headways.Top{headsign: "Chelsea"}, msg)
      end)
    end

    test "returns audio with values in ascending order regardless of range order" do
      msg1 = %{@msg | range: {10, 15}}
      msg2 = %{@msg | range: {15, 10}}

      Enum.each([msg1, msg2], fn msg ->
        assert {
                 %Content.Audio.VehiclesToDestination{
                   language: :english,
                   next_trip_mins: 10,
                   later_trip_mins: 15
                 },
                 %Content.Audio.VehiclesToDestination{
                   language: :spanish,
                   next_trip_mins: 10,
                   later_trip_mins: 15
                 }
               } = from_headway_message(%Content.Message.Headways.Top{headsign: "Chelsea"}, msg)
      end)
    end

    test "returns an english struct but not a spanish, if number is out of the latter range" do
      msg = %{@msg | range: {20, 25}}

      assert %Content.Audio.VehiclesToDestination{
               language: :english,
               next_trip_mins: 20,
               later_trip_mins: 25
             } = from_headway_message(%Content.Message.Headways.Top{headsign: "Chelsea"}, msg)
    end
  end
end
