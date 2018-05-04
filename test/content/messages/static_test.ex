defmodule Content.Message.StaticTest do
  use ExUnit.Case

  describe "to_string/1" do
    test "displays whatever is on the sign" do
      assert Content.Message.to_string(%Content.Message.Static{text: "Bridge is up"}) == "Bridge is up"
    end
  end
end
