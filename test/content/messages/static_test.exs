defmodule Content.Message.StaticTest do
  use ExUnit.Case

  describe "to_string/1" do
    test "displays whatever is on the sign" do
      msg = Content.Message.Static.new(text: "Bridge is up")
      assert Content.Message.Static.to_string(msg) == "Bridge is up"
    end
  end
end
