defmodule Content.Message.Bridge.DelaysTest do
  use ExUnit.Case

  describe "to_string/1" do
    test "says expect delays" do
      msg = Content.Message.Bridge.Delays.new()
      assert Content.Message.to_string(msg) == "Expect SL3 delays"
    end
  end
end
