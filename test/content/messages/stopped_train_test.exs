defmodule Content.Message.StoppedTrainTest do
  use ExUnit.Case, async: true

  describe "to_string/1" do
    test "returns BRD string if stopped 0 stops away" do
      msg = %Content.Message.StoppedTrain{headsign: "Ashmont", stops_away: 0}
      assert Content.Message.to_string(msg) == "Ashmont        BRD"
    end

    test "returns tuple of stopped away pages otherwise" do
      msg = %Content.Message.StoppedTrain{headsign: "Braintree", stops_away: 2}
      assert Content.Message.to_string(msg) == {
        [
          "Braintree  Stopped",
          "Braintree  2 stops",
          "Braintree  away   "
        ],
        5
      }
    end

    test "if only 1 stop away, doesn't pluralize, and adjusts spacing" do
      msg = %Content.Message.StoppedTrain{headsign: "Braintree", stops_away: 1}
      assert Content.Message.to_string(msg) == {
        [
          "Braintree  Stopped",
          "Braintree  1 stop ",
          "Braintree  away   "
        ],
        5
      }
    end
  end
end
