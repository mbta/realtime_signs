defmodule Engine.ConfigTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  describe "sign_config/2" do
    test "is auto when the sign is enabled" do
      Engine.Config.update()

      :timer.sleep(100)
      assert Engine.Config.sign_config("chelsea_inbound") == :auto
    end

    test "is off when the sign is disabled" do
      Engine.Config.update()

      :timer.sleep(100)
      assert Engine.Config.sign_config("chelsea_outbound") == :off
    end

    test "is auto when the sign is unspecified" do
      Engine.Config.update()

      :timer.sleep(100)
      assert Engine.Config.sign_config("unspecified_sign") == :auto
    end

    test "returns custom text when it's not expired" do
      state =
        initialize_test_state(:config_test_non_expired, fn ->
          Timex.to_datetime(~N[2017-07-04 07:00:00], "America/New_York")
        end)

      assert Engine.Config.sign_config(state.ets_table_name, "custom_text_test") ==
               {:static_text, {"Test message", "Please ignore"}}
    end

    test "does not return custom text when it's expired" do
      state =
        initialize_test_state(:config_test_expired, fn ->
          Timex.to_datetime(~N[2017-07-04 09:00:00], "America/New_York")
        end)

      assert Engine.Config.sign_config(state.ets_table_name, "custom_text_test") == :auto
    end

    test "properly returns headway mode" do
      Engine.Config.update()

      :timer.sleep(100)
      assert Engine.Config.sign_config("headway_test") == :headway
    end
  end

  describe "hanfle_info/2" do
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
      _state = initialize_test_state(:config_test_off, fn -> DateTime.utc_now() end)

      assert :ets.lookup(:config_test_off, "off_test") == [{"off_test", :off}]
    end

    test "correctly loads config for a sigh with a mode of \"auto\"" do
      _state = initialize_test_state(:config_test_auto, fn -> DateTime.utc_now() end)

      assert :ets.lookup(:config_test_auto, "auto_test") == [{"auto_test", :auto}]
    end

    test "correctly loads config for a sigh with a mode of \"headway\"" do
      _state = initialize_test_state(:config_test_headway, fn -> DateTime.utc_now() end)

      assert :ets.lookup(:config_test_headway, "headway_test") == [{"headway_test", :headway}]
    end

    test "logs a when an unknown message is received" do
      log =
        capture_log([level: :info], fn ->
          {:noreply, state} =
            Engine.Config.handle_info(:foo, %{
              ets_table_name: :test,
              current_version: "unchanged",
              time_fetcher: fn -> DateTime.utc_now() end
            })
        end)

      assert log =~ "unknown message: :foo"
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
