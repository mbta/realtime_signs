defmodule Content.Message.Bridge.UpTest do
  use ExUnit.Case

  describe "to_string/1" do
    test "says bridge is up" do
      msg = Content.Message.Bridge.Up.new()
      assert Content.Message.to_string(%Content.Message.Bridge.Up{}) == "Bridge is up"
    end
  end
end
