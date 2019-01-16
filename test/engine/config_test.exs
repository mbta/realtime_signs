defmodule Engine.ConfigTest do
  use ExUnit.Case, async: false

  describe "enabled?/1" do
    test "is true when the sign is enabled" do
      Engine.Config.update()

      :timer.sleep(100)
      assert Engine.Config.enabled?("chelsea_inbound") == true
    end

    test "is false when the sign is disabled" do
      Engine.Config.update()

      :timer.sleep(100)
      assert Engine.Config.enabled?("chelsea_outbound") == false
    end

    test "is true when the sign is unspecified" do
      Engine.Config.update()

      :timer.sleep(100)
      assert Engine.Config.enabled?("unspecified_sign") == true
    end
  end

  describe "custom_text" do
    test "returns custom text when it's not expired" do
      state =
        initialize_test_state(:config_test_non_expired, fn ->
          Timex.to_datetime(~N[2017-07-04 07:00:00], "America/New_York")
        end)

      assert Engine.Config.custom_text(state.ets_table_name, "custom_text_test") ==
               {"Test message", "Please ignore"}
    end

    test "does not return custom text when it's expired" do
      state =
        initialize_test_state(:config_test_expired, fn ->
          Timex.to_datetime(~N[2017-07-04 09:00:00], "America/New_York")
        end)

      assert Engine.Config.custom_text(state.ets_table_name, "custom_text_test") == nil
    end

    test "returns nil when feature flag is disabled" do
      old_env = Application.get_env(:realtime_signs, :static_text_enabled?)
      Application.put_env(:realtime_signs, :static_text_enabled?, false)
      on_exit(fn -> Application.put_env(:realtime_signs, :static_text_enabled?, old_env) end)

      state =
        initialize_test_state(:config_test_non_expired, fn ->
          Timex.to_datetime(~N[2017-07-04 07:00:00], "America/New_York")
        end)

      assert Engine.Config.custom_text(state.ets_table_name, "custom_text_test") == nil
    end
  end

  describe "update callback" do
    test "does not update config when it is unchanged" do
      {:noreply, state} =
        Engine.Config.handle_info(:update, %{
          ets_table_name: :test,
          current_version: "unchanged",
          time_fetcher: fn -> DateTime.utc_now() end
        })

      assert state[:current_version] == "unchanged"
    end

    test "correctly loads config for a sigh with a mode of \"off\"" do
      state = initialize_test_state(:config_test_off, fn -> DateTime.utc_now() end)

      assert :ets.lookup(:config_test_off, "off_test") == [{"off_test", :off}]
    end

    test "correctly loads config for a sigh with a mode of \"auto\"" do
      state = initialize_test_state(:config_test_auto, fn -> DateTime.utc_now() end)

      assert :ets.lookup(:config_test_auto, "auto_test") == [{"auto_test", :auto}]
    end

    test "correctly loads config for a sigh with a mode of \"headway\"" do
      state = initialize_test_state(:config_test_headway, fn -> DateTime.utc_now() end)

      assert :ets.lookup(:config_test_headway, "headway_test") == [{"headway_test", :headway}]
    end
  end

  @spec initialize_test_state(:ets.tab(), (() -> DateTime.t())) :: Engine.Config.t()
  defp initialize_test_state(ets_table_name, time_fetcher) do
    ^ets_table_name =
      :ets.new(ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

    state = %{
      ets_table_name: ets_table_name,
      current_version: nil,
      time_fetcher: time_fetcher
    }

    {:noreply, state} = Engine.Config.handle_info(:update, state)

    state
  end
end
