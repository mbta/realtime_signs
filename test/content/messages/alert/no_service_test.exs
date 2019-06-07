defmodule Content.Message.Alert.NoServiceTest do
  use ExUnit.Case, async: true

  describe "transit_mode_for_routes/1" do
    test "Returns :train if any of the routes isn't a Silver Line route" do
      assert Content.Message.Alert.NoService.transit_mode_for_routes(["Red"]) == :train
      assert Content.Message.Alert.NoService.transit_mode_for_routes(["Orange", "741"]) == :train
    end

    test "Returns :none when all routes are Silver Line" do
      assert Content.Message.Alert.NoService.transit_mode_for_routes(["741", "742"]) == :none
    end

    test "Returns :none when no routes given" do
      assert Content.Message.Alert.NoService.transit_mode_for_routes([]) == :none
    end
  end

  describe "to_string" do
    test "serializes modes correctly" do
      msg = %Content.Message.Alert.NoService{mode: :train}
      assert Content.Message.to_string(msg) == "No train service"
      msg = %Content.Message.Alert.NoService{mode: :none}
      assert Content.Message.to_string(msg) == "No service"
    end
  end
end
