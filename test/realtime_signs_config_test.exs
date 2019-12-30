defmodule RealtimeSignsConfigTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  import RealtimeSignsConfig

  setup do
    on_exit(fn -> Application.delete_env(:realtime_signs, :app_key) end)
  end

  describe "update_env/5" do
    test "sets the application environment" do
      assert :ok = update_env(%{"ENV_VAR" => "foo"}, :app_key, "ENV_VAR")
      assert Application.get_env(:realtime_signs, :app_key) == "foo"
    end

    test "still returns :ok if missing, and doesn't update app environment" do
      assert :ok = update_env(%{}, :app_key, "ENV_VAR")
      assert Application.get_env(:realtime_signs, :app_key) == nil
    end

    test "converts an integer before storing in application environment" do
      assert :ok = update_env(%{"ENV_VAR" => "5"}, :app_key, "ENV_VAR", type: :integer)
      assert Application.get_env(:realtime_signs, :app_key) == 5
    end

    test "logs the environment variable unless it's private" do
      env = %{"ENV1" => "env1", "ENV2" => "env2"}

      log =
        capture_log(fn ->
          :ok = update_env(env, :app_key, "ENV1")
          :ok = update_env(env, :app_key, "ENV2", private?: true)
          :ok = Process.sleep(50)
        end)

      assert log =~ ~s(ENV1="env1")
      refute log =~ "ENV2"
    end
  end
end
