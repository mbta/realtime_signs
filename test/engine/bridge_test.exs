defmodule Engine.BridgeTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  describe "status/2" do
    test "gives the status for the bridge id provided" do
      ets_table_name = :bridge_status_test

      {:ok, %{ets_table_name: ^ets_table_name}} =
        Engine.Bridge.init(ets_table_name: ets_table_name)

      :ets.insert(ets_table_name, [{"1", {"Lowered", nil}}])

      assert Engine.Bridge.status(ets_table_name, "1") == {"Lowered", nil}
    end

    test "handles a bridge id for which we don't have information" do
      ets_table_name = :bridge_status_test_nonexistent_bridge

      {:ok, %{ets_table_name: ^ets_table_name}} =
        Engine.Bridge.init(ets_table_name: ets_table_name)

      :ets.insert(ets_table_name, [{"1", {"Raised", 4}}])

      assert Engine.Bridge.status(ets_table_name, "2") == nil
    end
  end

  describe "update callback" do
    test "calls the bridge requestor" do
      ets_table_name = :bridge_update_test

      {:ok, %{ets_table_name: ^ets_table_name} = state} =
        Engine.Bridge.init(ets_table_name: ets_table_name)

      Engine.Bridge.handle_info(:update, state)

      assert Engine.Bridge.status(ets_table_name, "1") == {"Raised", 4}
    end
  end
end
