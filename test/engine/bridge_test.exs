defmodule Engine.BridgeTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  describe "status callback" do
    test "gives the status for the bridge id provided" do
      assert Engine.Bridge.handle_call({:status, "1"}, %{}, %{"1" => {"Raised", 4}}) ==
               {:reply, {"Raised", 4}, %{"1" => {"Raised", 4}}}
    end
  end

  describe "update callback" do
    test "calls the bridge requestor" do
      log =
        capture_log([level: :info], fn ->
          Engine.Bridge.handle_info(:update, %{"1" => %{}})
        end)

      assert log != "update_single_line called"
    end
  end

  describe "status/2" do
    test "gets teh status of the bridge" do
      {:ok, pid} = GenServer.start_link(Engine.Bridge, :test_bridge_engine)
      Engine.Bridge.update(pid)
      assert Engine.Bridge.status(pid, "1") == {"Raised", 4}
    end
  end
end
