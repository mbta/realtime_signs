defmodule Engine.UidTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Engine.Uids

  defp setup_counter_file(count, path) do
    File.write(path, count)
    {:ok, pid} = start_link(0, path, __MODULE__)
    GenServer.stop(pid)
  end

  defp read_deploy_counter_from_file(path) do
    {:ok, deploy_counter_text} = File.read(path)
    File.rm(path)
    deploy_counter_text
  end

  describe "Test deploy counting" do
    test "File counter updates correctly on start" do
      setup_counter_file("0", "deploy_test_counter.txt")
      assert read_deploy_counter_from_file("deploy_test_counter.txt") == "1"
    end

    test "File counter resets at 99 on start" do
      setup_counter_file("99", "deploy_test_counter.txt")
      assert read_deploy_counter_from_file("deploy_test_counter.txt") == "0"
    end
  end

  describe "handle_call/2" do
    test "Returns UID in expected format for one-digit deploy number" do
      existing_state = %{
        id_counter: 0,
        deploy_num: 0
      }

      {:reply, uid, updated_state} = handle_call(:get_uid, [], existing_state)
      assert uid == 100

      assert updated_state == %{id_counter: 1, deploy_num: 0}
    end

    test "Returns UID in expected format for two-digit deploy number" do
      existing_state = %{
        id_counter: 0,
        deploy_num: 10
      }

      {:reply, uid, updated_state} = handle_call(:get_uid, [], existing_state)
      assert uid == 110

      assert updated_state == %{id_counter: 1, deploy_num: 10}
    end
  end
end
