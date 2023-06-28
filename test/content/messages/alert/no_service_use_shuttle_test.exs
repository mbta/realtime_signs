defmodule Content.Message.Alert.NoServiceUseShuttleTest do
  use ExUnit.Case, async: true

  describe "to_string" do
    test "serializes pages correctly" do
      msg = %Content.Message.Alert.NoServiceUseShuttle{destination: :medford_tufts}

      assert Content.Message.to_string(msg) == [
               {"Medfd/Tufts   no service", 6},
               {"Medfd/Tufts  use shuttle", 6}
             ]
    end
  end
end
