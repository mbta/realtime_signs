defmodule Content.Audio.ApproachingTest do
  use ExUnit.Case, async: true

  alias Content.Audio.Approaching

  describe "to_params/1" do
    test "Returns params when platform is present" do
      audio = %Approaching{destination: :alewife, platform: :braintree, route_id: "Red"}
      assert Content.Audio.to_params(audio) == {:canned, {"103", ["32126"], :audio_visual}}
    end

    test "Returns params when platform is not present" do
      audio = %Approaching{destination: :oak_grove, route_id: "Orange"}
      assert Content.Audio.to_params(audio) == {:canned, {"103", ["32122"], :audio_visual}}
    end

    test "Returns ad-hoc audio for valid destinations" do
      audio = %Approaching{destination: :northbound, route_id: "Orange"}

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc,
                {"Attention passengers: The next Northbound Orange Line train is now approaching.",
                 :audio_visual}}
    end

    test "Returns nil for Green Line trips" do
      audio = %Approaching{destination: :riverside, route_id: "Green-D"}
      assert Content.Audio.to_params(audio) == nil
    end

    test "Returns nil when destination is Ashmont on the Mattapan line" do
      audio = %Approaching{destination: :ashmont, route_id: "Mattapan"}
      assert Content.Audio.to_params(audio) == nil
    end

    test "Returns nil when destination for which we don't have audio" do
      audio = %Approaching{destination: :unknown, route_id: "Red"}
      assert Content.Audio.to_params(audio) == nil
    end

    test "No longer returns params for new Orange Line cars" do
      audio = %Approaching{destination: :oak_grove, route_id: "Orange", new_cars?: true}

      assert Content.Audio.to_params(audio) ==
               {:canned, {"103", ["32122"], :audio_visual}}
    end

    test "Returns params for new Red Line cars" do
      audio = %Approaching{destination: :alewife, route_id: "Red", new_cars?: true}

      assert Content.Audio.to_params(audio) ==
               {:canned, {"106", ["783", "4000", "21000", "786"], :audio_visual}}
    end

    test "Falls back on audio without new cars message if needed" do
      audio = %Approaching{destination: :bowdoin, route_id: "Blue", new_cars?: true}
      assert Content.Audio.to_params(audio) == {:canned, {"103", ["32121"], :audio_visual}}
    end

    test "Returns params when destination is 'southbound'" do
      audio = %Approaching{destination: :southbound, route_id: "Red"}

      assert Content.Audio.to_params(audio) ==
               {:ad_hoc,
                {"Attention passengers: The next Southbound Red Line train is now approaching.",
                 :audio_visual}}
    end

    test "Returns crowding info" do
      audio = %Approaching{
        destination: :forest_hills,
        route_id: "Orange",
        crowding_description: {:train_level, :crowded}
      }

      assert Content.Audio.to_params(audio) ==
               {:canned, {"104", ["32123", "21000", "876"], :audio_visual}}
    end
  end
end
