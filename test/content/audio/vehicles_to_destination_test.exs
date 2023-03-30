defmodule Content.Audio.VehiclesToDestinationTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  import Content.Audio.VehiclesToDestination

  describe "to_params/1" do
    test "Buses to Chelsea in English" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :chelsea,
        language: :english,
        headway_range: {7, 10}
      }

      assert Content.Audio.to_params(audio) == {:canned, {"133", ["5507", "5510"], :audio}}
    end

    test "Buses to Chelsea in Spanish" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :chelsea,
        language: :spanish,
        headway_range: {7, 10}
      }

      assert Content.Audio.to_params(audio) == {:canned, {"150", ["37007", "37010"], :audio}}
    end

    test "Buses to South Station in English" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :south_station,
        language: :english,
        headway_range: {7, 10}
      }

      assert Content.Audio.to_params(audio) == {:canned, {"134", ["5507", "5510"], :audio}}
    end

    test "Buses to South Station in Spanish" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :south_station,
        language: :spanish,
        headway_range: {7, 10}
      }

      assert Content.Audio.to_params(audio) == {:canned, {"151", ["37007", "37010"], :audio}}
    end

    test "Buses to South Station in Spanish, headway out of range" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :south_station,
        language: :spanish,
        headway_range: {19, 21}
      }

      log =
        capture_log([level: :warn], fn ->
          assert Content.Audio.to_params(audio) == nil
        end)

      assert log =~ "no_audio_for_headway_range"
    end

    test "returns a robo-voice message for headways with a last departure" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :lechmere,
        language: :english,
        headway_range: {5, 7},
        previous_departure_mins: 5
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc,
                {"Trains to Lechmere every 5 to 7 minutes.  Previous departure 5 minutes ago.",
                 :audio}}
    end

    test "singularizes the minutes when the last departure was one minute ago" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :lechmere,
        language: :english,
        headway_range: {5, 7},
        previous_departure_mins: 1
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc,
                {"Trains to Lechmere every 5 to 7 minutes.  Previous departure 1 minute ago.",
                 :audio}}
    end

    test "doesn't announce departure zero minute ago" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :lechmere,
        language: :english,
        headway_range: {5, 7},
        previous_departure_mins: 0
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc, {"Trains to Lechmere every 5 to 7 minutes.", :audio}}
    end

    test "returns a robo-voice message for a headway range that is too big" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :lechmere,
        language: :english,
        headway_range: {:up_to, 20},
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
        headway_range: {:up_to, 20}
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc, {"Trains to Lechmere up to every 20 minutes.", :audio}}
    end

    test "returns correct audio for cardinal direction, rather than terminal, headways" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :southbound,
        language: :english,
        headway_range: {5, 7},
        previous_departure_mins: 3
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc,
                {"Southbound trains every 5 to 7 minutes.  Previous departure 3 minutes ago.",
                 :audio}}
    end

    test "returns nil when range is unexpected" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :lechmere,
        language: :english,
        headway_range: {:a, :b, :c}
      }

      assert Content.Audio.to_params(audio) == nil
    end

    test "Returns ad-hoc audio when no destination" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: nil,
        language: :english,
        headway_range: {8, 10},
        previous_departure_mins: nil
      }

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc, {"Trains every 8 to 10 minutes.", :audio}}
    end
  end

  describe "from_headway_message/2" do
    @msg %Content.Message.Headways.Bottom{range: {5, 7}}

    test "returns an audio message from a headway message to chelsea" do
      assert [
               %Content.Audio.VehiclesToDestination{language: :english, destination: :chelsea},
               %Content.Audio.VehiclesToDestination{language: :spanish, destination: :chelsea}
             ] = from_headway_message(%Content.Message.Headways.Top{destination: :chelsea}, @msg)
    end

    test "returns an audio message from a headway message to red/orange/blue/green line terminals" do
      # green line
      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :lechmere
               }
             ] = from_headway_message(%Content.Message.Headways.Top{destination: :lechmere}, @msg)

      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :union_sq
               }
             ] = from_headway_message(%Content.Message.Headways.Top{destination: :union_sq}, @msg)

      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :government_center
               }
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :government_center},
                 @msg
               )

      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :north_station
               }
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :north_station},
                 @msg
               )

      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :park_street
               }
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :park_street},
                 @msg
               )

      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :heath_street
               }
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :heath_street},
                 @msg
               )

      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :riverside
               }
             ] =
               from_headway_message(%Content.Message.Headways.Top{destination: :riverside}, @msg)

      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :boston_college
               }
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :boston_college},
                 @msg
               )

      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :cleveland_circle
               }
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :cleveland_circle},
                 @msg
               )

      # blue line
      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :bowdoin
               }
             ] = from_headway_message(%Content.Message.Headways.Top{destination: :bowdoin}, @msg)

      assert [
               %Content.Audio.VehiclesToDestination{language: :english, destination: :wonderland}
             ] =
               from_headway_message(%Content.Message.Headways.Top{destination: :wonderland}, @msg)

      # orange line
      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :forest_hills
               }
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :forest_hills},
                 @msg
               )

      assert [
               %Content.Audio.VehiclesToDestination{language: :english, destination: :oak_grove}
             ] =
               from_headway_message(%Content.Message.Headways.Top{destination: :oak_grove}, @msg)

      # red line
      assert [
               %Content.Audio.VehiclesToDestination{language: :english, destination: :alewife}
             ] = from_headway_message(%Content.Message.Headways.Top{destination: :alewife}, @msg)

      assert [
               %Content.Audio.VehiclesToDestination{language: :english, destination: :ashmont}
             ] = from_headway_message(%Content.Message.Headways.Top{destination: :ashmont}, @msg)

      assert [
               %Content.Audio.VehiclesToDestination{language: :english, destination: :braintree}
             ] =
               from_headway_message(%Content.Message.Headways.Top{destination: :braintree}, @msg)
    end

    test "returns an audio message from a headway message to south station" do
      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: :south_station
               },
               %Content.Audio.VehiclesToDestination{
                 language: :spanish,
                 destination: :south_station
               }
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :south_station},
                 @msg
               )
    end

    test "handles a nil destination in English" do
      assert [
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 destination: nil,
                 headway_range: {8, 10},
                 previous_departure_mins: nil
               }
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: nil, vehicle_type: :train},
                 %Content.Message.Headways.Bottom{range: {8, 10}, prev_departure_mins: nil}
               )
    end

    test "returns nils for an unknown destination" do
      log =
        capture_log([level: :warn], fn ->
          assert from_headway_message(:foo, :bar) == []
        end)

      assert log =~ "message_to_audio_error"
    end
  end
end
