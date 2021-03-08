defmodule Content.Message.StoppedAtStationTest do
  use ExUnit.Case, async: true

  alias Content.Message.StoppedAtStation
  alias Predictions.Prediction

  describe "from_prediction/1" do
    test "Converts the stops away to the station atom, SB" do
      assert %StoppedAtStation{
               destination: :forest_hills,
               stopped_at: :assembly
             } =
               StoppedAtStation.from_prediction(%Prediction{
                 stop_id: "70024",
                 stops_away: 4,
                 direction_id: 0,
                 route_id: "Orange"
               })
    end

    test "Converts the stops away to the station atom, NB" do
      assert %StoppedAtStation{
               destination: :oak_grove,
               stopped_at: :tufts_medical_center
             } =
               StoppedAtStation.from_prediction(%Prediction{
                 stop_id: "70029",
                 stops_away: 6,
                 route_id: "Orange",
                 direction_id: 1
               })
    end

    test "Converts the stops away to the station atom, wrapping around" do
      assert %StoppedAtStation{
               destination: :forest_hills,
               stopped_at: :wellington
             } =
               StoppedAtStation.from_prediction(%Prediction{
                 stop_id: "70278",
                 stops_away: 5,
                 route_id: "Orange",
                 direction_id: 0
               })
    end

    test "Converts the stops away to the station atom, wrapping around the other way" do
      assert %StoppedAtStation{
               destination: :oak_grove,
               stopped_at: :roxbury_crossing
             } =
               StoppedAtStation.from_prediction(%Prediction{
                 stop_id: "70007",
                 stops_away: 7,
                 route_id: "Orange",
                 direction_id: 1
               })
    end

    test "Counts the correct direction from single tracked Wellington, NB" do
      assert %StoppedAtStation{
               destination: :oak_grove,
               stopped_at: :sullivan_square
             } =
               StoppedAtStation.from_prediction(%Prediction{
                 stop_id: "70032",
                 stops_away: 2,
                 route_id: "Orange",
                 direction_id: 1
               })
    end

    test "Counts the correct direction from single tracked Wellington, SB" do
      assert %StoppedAtStation{
               destination: :forest_hills,
               stopped_at: :oak_grove
             } =
               StoppedAtStation.from_prediction(%Prediction{
                 stop_id: "70032",
                 stops_away: 2,
                 route_id: "Orange",
                 direction_id: 0
               })
    end

    test "Handles unknown destination" do
      assert is_nil(
               StoppedAtStation.from_prediction(%Prediction{
                 route_id: "Orange",
                 direction_id: 2,
                 destination_stop_id: ""
               })
             )
    end
  end

  describe "to_string protocol" do
    test "Converts a struct into the text that appears on the sign" do
      assert [
               {"Oak Grove waiting ", 6},
               {"at Wellington     ", 3}
             ] =
               Content.Message.to_string(%StoppedAtStation{
                 destination: :oak_grove,
                 stopped_at: :wellington
               })
    end
  end
end
