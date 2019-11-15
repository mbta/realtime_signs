defmodule Signs.Utilities.SignsConfigTest do
  use ExUnit.Case

  require Signs.Utilities.SignsConfig

  describe "all_stop_ids" do
    test "includes a platform sign" do
      assert Enum.member?(Signs.Utilities.SignsConfig.all_stop_ids(), "70058")
    end

    test "includes a mezzanine sign" do
      assert Enum.member?(Signs.Utilities.SignsConfig.all_stop_ids(), "70056")
    end
  end
end
