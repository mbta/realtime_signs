defmodule Content.Message.StopsAwayTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  alias Content.Message.StopsAway

  @prediction %Predictions.Prediction{
    route_id: "Red",
    direction_id: 1,
    stops_away: 1
  }

  describe "from_prediction/1" do
    test "returns a stops away struct with valid headsign" do
      prediction = %{@prediction | route_id: "Red", destination_stop_id: "70061"}

      assert StopsAway.from_prediction(prediction) ==
               %Content.Message.StopsAway{
                 headsign: "Alewife",
                 stops_away: 1
               }
    end

    test "returns a stops away struct with invalid headsign" do
      prediction = %{@prediction | route_id: "Fake", destination_stop_id: "123"}

      log =
        capture_log([level: :warn], fn ->
          assert StopsAway.from_prediction(prediction) ==
                   %Content.Message.StopsAway{
                     headsign: "",
                     stops_away: 1
                   }
        end)

      assert log =~ "Could not find headsign"
    end
  end

  describe "to_string/1" do
    test "Serializes struct to paginated strings when multiple stops away" do
      message = %StopsAway{headsign: "Alewife", stops_away: 2}

      assert Content.Message.to_string(message) == [
               {"Alewife       away", 3},
               {"Alewife    2 stops", 3}
             ]
    end

    test "Serializes struct to paginated strings when one stop away" do
      message = %StopsAway{headsign: "Alewife", stops_away: 1}

      assert Content.Message.to_string(message) == [
               {"Alewife       away", 3},
               {"Alewife     1 stop", 3}
             ]
    end
  end
end
