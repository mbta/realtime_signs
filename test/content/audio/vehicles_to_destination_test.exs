defmodule Content.Audio.VehiclesToDestinationTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  import Content.Audio.VehiclesToDestination

  test "Buses to Chelsea in English" do
    audio = %Content.Audio.VehiclesToDestination{
      destination: :chelsea,
      language: :english,
      next_trip_mins: 7,
      later_trip_mins: 10
    }

    assert Content.Audio.to_params(audio) == {"133", ["5507", "5510"], :audio}
  end

  test "Buses to Chelsea in Spanish" do
    audio = %Content.Audio.VehiclesToDestination{
      destination: :chelsea,
      language: :spanish,
      next_trip_mins: 7,
      later_trip_mins: 10
    }

    assert Content.Audio.to_params(audio) == {"150", ["37007", "37010"], :audio}
  end

  test "Buses to South Station in English" do
    audio = %Content.Audio.VehiclesToDestination{
      destination: :south_station,
      language: :english,
      next_trip_mins: 7,
      later_trip_mins: 10
    }

    assert Content.Audio.to_params(audio) == {"134", ["5507", "5510"], :audio}
  end

  test "Buses to South Station in Spanish" do
    audio = %Content.Audio.VehiclesToDestination{
      destination: :south_station,
      language: :spanish,
      next_trip_mins: 7,
      later_trip_mins: 10
    }

    assert Content.Audio.to_params(audio) == {"151", ["37007", "37010"], :audio}
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
               destination: :govt_ctr
             } = from_headway_message(%Content.Message.Headways.Top{headsign: "Govt Ctr"}, @msg)

      assert %Content.Audio.VehiclesToDestination{
               language: :english,
               destination: :north_sta
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

    test "returns a robo-voice message for headways with a last departure" do
      assert %Content.Audio.Custom{
               message:
                 "Trains to Lechmere every 5 to 7 minutes.  Previous departure 5 minutes ago"
             } =
               from_headway_message(
                 %Content.Message.Headways.Top{headsign: "Lechmere"},
                 %Content.Message.Headways.Bottom{@msg | last_departure: 5}
               )
    end

    test "returns a robo-voice message for a single-number headway with a last departure" do
      assert %Content.Audio.Custom{
               message: "Trains to Lechmere every 8 minutes.  Previous departure 5 minutes ago"
             } =
               from_headway_message(
                 %Content.Message.Headways.Top{headsign: "Lechmere"},
                 %Content.Message.Headways.Bottom{@msg | range: {8, nil}, last_departure: 5}
               )
    end

    test "singularizes the minutes when the last departure was one minute ago" do
      assert %Content.Audio.Custom{
               message: "Trains to Lechmere every 8 minutes.  Previous departure 1 minute ago"
             } =
               from_headway_message(
                 %Content.Message.Headways.Top{headsign: "Lechmere"},
                 %Content.Message.Headways.Bottom{@msg | range: {8, nil}, last_departure: 1}
               )
    end

    test "unabreviates the headsign before putting it in custom message" do
      assert %Content.Audio.Custom{
               message: "Trains to Forest Hills every 8 minutes.  Previous departure 1 minute ago"
             } =
               from_headway_message(
                 %Content.Message.Headways.Top{headsign: "Frst Hills"},
                 %Content.Message.Headways.Bottom{@msg | range: {8, nil}, last_departure: 1}
               )
    end

    test "returns a robo-voice message for a {nil, nil} headway with a last departure" do
      assert %Content.Audio.Custom{
               message: ""
             } =
               from_headway_message(
                 %Content.Message.Headways.Top{headsign: "Lechmere"},
                 %Content.Message.Headways.Bottom{@msg | range: {nil, nil}, last_departure: 5}
               )
    end

    test "returns a robo-voice message for a :none headway with a last departure" do
      assert %Content.Audio.Custom{
               message: ""
             } =
               from_headway_message(
                 %Content.Message.Headways.Top{headsign: "Lechmere"},
                 %Content.Message.Headways.Bottom{@msg | range: :none, last_departure: 5}
               )
    end
  end
end
