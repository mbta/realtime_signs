defmodule Content.Message.Bridge.DelaysTest do
  use ExUnit.Case

  describe "to_string/1" do
    test "says expect delays" do
      assert Content.Message.to_string(%Content.Message.Bridge.Delays{}) == "Expect SL3 delays"
    end
  end
end
