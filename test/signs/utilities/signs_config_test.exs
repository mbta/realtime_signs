defmodule Signs.Utilities.SignsConfigTest do
  use ExUnit.Case

  require Signs.Utilities.SignsConfig

  describe "all_train_stop_ids" do
    test "includes a platform sign" do
      assert Enum.member?(Signs.Utilities.SignsConfig.all_train_stop_ids(), "70058")
    end

    test "includes a mezzanine sign" do
      assert Enum.member?(Signs.Utilities.SignsConfig.all_train_stop_ids(), "70056")
    end
  end

  describe "all_bus_stop_ids" do
    test "empty for now" do
      assert Signs.Utilities.SignsConfig.all_bus_stop_ids() == []
    end
  end
end
