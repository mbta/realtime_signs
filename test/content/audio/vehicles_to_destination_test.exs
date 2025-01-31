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
end
