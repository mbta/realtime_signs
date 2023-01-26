defmodule Content.Message.Alert.DestinationNoServiceTest do
  use ExUnit.Case, async: true

  describe "to_string" do
    test "serializes correctly" do
      msg = %Content.Message.Alert.DestinationNoService{destination: :medford_tufts}
      assert Content.Message.to_string(msg) == "Medfd/Tufts   no service"
    end
  end
end
