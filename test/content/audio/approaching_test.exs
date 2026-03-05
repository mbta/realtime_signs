defmodule Content.Audio.ApproachingTest do
  use ExUnit.Case, async: true

  alias Content.Audio.Approaching

  describe "to_params/1" do
    test "Returns params when platform is present" do
      audio = %Approaching{destination: :"place-alfcl", platform: :braintree, route_id: "Red"}

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"114", spaced(["896", "892", "920", "910", "901", "21014", "925"]),
                 :audio_visual}}
    end

    test "Returns params when platform is not present" do
      audio = %Approaching{destination: :"place-ogmnl", route_id: "Orange"}

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"112", spaced(["896", "915", "920", "910", "21014", "925"]), :audio_visual}}
    end

    test "Returns params for Green Line trips" do
      audio = %Approaching{destination: :"place-river", route_id: "Green-D"}

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"114", spaced(["896", "905", "919", "918", "910", "21014", "925"]),
                 :audio_visual}}
    end

    test "Returns params for new Red Line cars" do
      audio = %Approaching{destination: :"place-alfcl", route_id: "Red", new_cars?: true}

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"115", spaced(["896", "892", "920", "910", "21012", "893", "21014", "925"]),
                 :audio_visual}}
    end

    test "Returns crowding info" do
      audio = %Approaching{
        destination: :"place-forhl",
        route_id: "Orange",
        crowding_description: {:train_level, :crowded}
      }

      assert Content.Audio.to_params(audio) ==
               {:canned,
                {"114", spaced(["896", "907", "920", "910", "21014", "925", "876"]),
                 :audio_visual}}
    end
  end

  defp spaced(list), do: PaEss.Utilities.pad_takes(list)
end
