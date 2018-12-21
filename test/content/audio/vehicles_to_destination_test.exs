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

  describe "from_headway_message/2" do
    @msg %Content.Message.Headways.Bottom{range: {5, 7}}

    test "returns an audio message from a headway message to chelsea" do
      assert {
               %Content.Audio.VehiclesToDestination{language: :english, destination: :chelsea},
               %Content.Audio.VehiclesToDestination{language: :spanish, destination: :chelsea}
             } = from_headway_message(@msg, "Chelsea")
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
             } = from_headway_message(@msg, "South Station")
    end

    test "returns nils for an unknown destination" do
      assert from_headway_message(@msg, "Unknown") == {nil, nil}
    end

    test "returns nils when range is all nil, but doesn't warn" do
      msg = %{@msg | range: {nil, nil}}

      log =
        capture_log([level: :warn], fn ->
          assert from_headway_message(msg, "Chelsea") == {nil, nil}
        end)

      refute log =~ "from_headway_message"
    end

    test "returns nil when range is unexpected" do
      msg = %{@msg | range: {:a, :b, :c}}
      assert from_headway_message(msg, "Chelsea") == {nil, nil}
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
               } = from_headway_message(msg, "Chelsea")
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
               } = from_headway_message(msg, "Chelsea")
      end)
    end

    test "returns an english struct but not a spanish, if number is out of the latter range" do
      msg = %{@msg | range: {20, 25}}

      assert {
               %Content.Audio.VehiclesToDestination{
                 language: :english,
                 next_trip_mins: 20,
                 later_trip_mins: 25
               },
               nil
             } = from_headway_message(msg, "Chelsea")
    end
  end
end
