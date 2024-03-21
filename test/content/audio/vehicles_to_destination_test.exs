defmodule Content.Audio.VehiclesToDestinationTest do
  use ExUnit.Case

  import Content.Audio.VehiclesToDestination

  describe "to_params/1" do
    test "Buses to Chelsea in English" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :chelsea,
        headway_range: {7, 10}
      }

      assert Content.Audio.to_params(audio) == {:canned, {"133", ["5507", "5510"], :audio}}
    end

    test "Buses to South Station in English" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :south_station,
        headway_range: {7, 10}
      }

      assert Content.Audio.to_params(audio) == {:canned, {"134", ["5507", "5510"], :audio}}
    end

    test "returns correct audio for cardinal direction, rather than terminal, headways" do
      audio = %Content.Audio.VehiclesToDestination{
        destination: :southbound,
        headway_range: {5, 7}
      }

      assert Content.Audio.to_params(audio) == {:canned, {"184", ["5505", "5507"], :audio}}
    end
  end

  describe "from_headway_message/2" do
    @msg %Content.Message.Headways.Bottom{range: {5, 7}}

    test "returns an audio message from a headway message to chelsea" do
      assert [
               %Content.Audio.VehiclesToDestination{destination: :chelsea}
             ] = from_headway_message(%Content.Message.Headways.Top{destination: :chelsea}, @msg)
    end

    test "returns an audio message from a headway message to red/orange/blue/green line terminals" do
      # green line
      assert [
               %Content.Audio.VehiclesToDestination{destination: :lechmere}
             ] = from_headway_message(%Content.Message.Headways.Top{destination: :lechmere}, @msg)

      assert [
               %Content.Audio.VehiclesToDestination{destination: :union_sq}
             ] = from_headway_message(%Content.Message.Headways.Top{destination: :union_sq}, @msg)

      assert [
               %Content.Audio.VehiclesToDestination{destination: :government_center}
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :government_center},
                 @msg
               )

      assert [
               %Content.Audio.VehiclesToDestination{destination: :north_station}
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :north_station},
                 @msg
               )

      assert [
               %Content.Audio.VehiclesToDestination{destination: :park_street}
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :park_street},
                 @msg
               )

      assert [
               %Content.Audio.VehiclesToDestination{destination: :heath_street}
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :heath_street},
                 @msg
               )

      assert [
               %Content.Audio.VehiclesToDestination{destination: :riverside}
             ] =
               from_headway_message(%Content.Message.Headways.Top{destination: :riverside}, @msg)

      assert [
               %Content.Audio.VehiclesToDestination{destination: :boston_college}
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :boston_college},
                 @msg
               )

      assert [
               %Content.Audio.VehiclesToDestination{destination: :cleveland_circle}
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :cleveland_circle},
                 @msg
               )

      # blue line
      assert [
               %Content.Audio.VehiclesToDestination{destination: :bowdoin}
             ] = from_headway_message(%Content.Message.Headways.Top{destination: :bowdoin}, @msg)

      assert [
               %Content.Audio.VehiclesToDestination{destination: :wonderland}
             ] =
               from_headway_message(%Content.Message.Headways.Top{destination: :wonderland}, @msg)

      # orange line
      assert [
               %Content.Audio.VehiclesToDestination{destination: :forest_hills}
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :forest_hills},
                 @msg
               )

      assert [
               %Content.Audio.VehiclesToDestination{destination: :oak_grove}
             ] =
               from_headway_message(%Content.Message.Headways.Top{destination: :oak_grove}, @msg)

      # red line
      assert [
               %Content.Audio.VehiclesToDestination{destination: :alewife}
             ] = from_headway_message(%Content.Message.Headways.Top{destination: :alewife}, @msg)

      assert [
               %Content.Audio.VehiclesToDestination{destination: :ashmont}
             ] = from_headway_message(%Content.Message.Headways.Top{destination: :ashmont}, @msg)

      assert [
               %Content.Audio.VehiclesToDestination{destination: :braintree}
             ] =
               from_headway_message(%Content.Message.Headways.Top{destination: :braintree}, @msg)
    end

    test "returns an audio message from a headway message to south station" do
      assert [
               %Content.Audio.VehiclesToDestination{destination: :south_station}
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: :south_station},
                 @msg
               )
    end

    test "handles a nil destination in English" do
      assert [
               %Content.Audio.VehiclesToDestination{
                 destination: nil,
                 headway_range: {8, 10}
               }
             ] =
               from_headway_message(
                 %Content.Message.Headways.Top{destination: nil, vehicle_type: :train},
                 %Content.Message.Headways.Bottom{range: {8, 10}}
               )
    end
  end
end
