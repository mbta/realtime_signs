defmodule RealtimeSignsConfigTest do
  use ExUnit.Case, async: false

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
  end
end
