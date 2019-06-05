defmodule Content.Message.Bridge.UpTest do
  use ExUnit.Case

  describe "to_string/1" do
    test "says bridge is up with no estimate" do
      msg = Content.Message.Bridge.Up.new(nil)
      assert Content.Message.to_string(msg) == "Chelsea St Bridge is up"
    end

    test "says bridge is up with time estimate" do
      msg = Content.Message.Bridge.Up.new(5)

      assert Content.Message.to_string(msg) == [
               {"Chelsea St Bridge is up", 2},
               {"for 5 more minutes", 2}
             ]
    end

    test "says bridge is up with time estimate of 1 minute" do
      msg = Content.Message.Bridge.Up.new(1)

      assert Content.Message.to_string(msg) == [
               {"Chelsea St Bridge is up", 2},
               {"for 1 more minute", 2}
             ]
    end
  end
end
