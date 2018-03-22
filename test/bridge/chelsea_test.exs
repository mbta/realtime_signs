defmodule Bridge.ChelseaTest do
  use ExUnit.Case, async: true
  import Bridge.Chelsea

  describe "raised/1" do
    test "returns true for raised status" do
      assert raised?("Raised")
    end

    test "returns false for lowered or nil status" do
      refute raised?("Lowered")
      refute raised?(nil)
    end
  end
end
