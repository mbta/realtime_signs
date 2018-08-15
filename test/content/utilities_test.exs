defmodule Content.UtilitiesTest do
  use ExUnit.Case, async: true

  import Content.Utilities

  describe "width_padded_string/3" do
    test "inserts spaces between left and right to reach given width" do
      assert width_padded_string("L", "R", 4) == "L  R"
    end
  end
end
