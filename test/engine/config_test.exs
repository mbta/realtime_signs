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

      assert Engine.Config.sign_config(state.table_name_signs, "custom_text_test") ==
               {:static_text, {"Test message", "Please ignore"}}
    end

    test "does not return custom text when it's expired" do
      state =
        initialize_test_state(:config_test_expired, fn ->
          Timex.to_datetime(~N[2017-07-04 09:00:00], "America/New_York")
        end)

      assert Engine.Config.sign_config(state.table_name_signs, "custom_text_test") == :auto
    end

    test "properly returns headway mode" do
      Engine.Config.update()

      :timer.sleep(100)
      assert Engine.Config.sign_config("headway_test") == :headway
    end
  end

  describe "handle_info/2" do
    test "does not update config when it is unchanged" do
      Engine.Config.Headways.create_table(:test_headways)

      {:noreply, state} =
        Engine.Config.handle_info(:update, %{
          table_name_signs: :test,
          table_name_headways: :test_headways,
          current_version: "unchanged",
          time_fetcher: fn -> DateTime.utc_now() end
        })

      assert state[:current_version] == "unchanged"
    end

    test "handles new format of config" do
      :ets.new(:test_new_format, [:set, :protected, :named_table, read_concurrency: true])
      Engine.Config.Headways.create_table(:test_headways)

      {:noreply, _state} =
        Engine.Config.handle_info(:update, %{
          table_name_signs: :test_new_format,
          table_name_headways: :test_headways,
          current_version: "new_format",
          time_fetcher: &DateTime.utc_now/0
        })

      assert :ets.lookup(:test_new_format, "some_custom_sign") == [
               {"some_custom_sign", {:static_text, {"custom", ""}}}
             ]
    end

    test "handles a config with multi-sign headways" do
      :ets.new(:test_signs, [:set, :protected, :named_table, read_concurrency: true])
      Engine.Config.Headways.create_table(:test_group_headways)

      {:noreply, _state} =
        Engine.Config.handle_info(:update, %{
          table_name_signs: :test_signs,
          table_name_headways: :test_group_headways,
          current_version: "headway_config",
          time_fetcher: &DateTime.utc_now/0
        })

      assert %Engine.Config.Headway{range_low: 8, range_high: 10} =
               Engine.Config.Headways.get_headway(:test_group_headways, "custom_headway")
    end

    test "correctly loads config for a sign with a mode of \"off\"" do
      _state = initialize_test_state(:config_test_off, fn -> DateTime.utc_now() end)

      assert :ets.lookup(:config_test_off, "off_test") == [{"off_test", :off}]
    end

    test "correctly loads config for a sign with a mode of \"auto\"" do
      _state = initialize_test_state(:config_test_auto, fn -> DateTime.utc_now() end)

      assert :ets.lookup(:config_test_auto, "auto_test") == [{"auto_test", :auto}]
    end

    test "correctly loads config for a sign with a mode of \"headway\"" do
      _state = initialize_test_state(:config_test_headway, fn -> DateTime.utc_now() end)

      assert :ets.lookup(:config_test_headway, "headway_test") == [{"headway_test", :headway}]
    end

    test "logs a when an unknown message is received" do
      log =
        capture_log([level: :info], fn ->
          {:noreply, _state} =
            Engine.Config.handle_info(:foo, %{
              table_name_signs: :test,
              table_name_headways: :test_headways,
              current_version: "unchanged",
              time_fetcher: fn -> DateTime.utc_now() end
            })
        end)

      assert log =~ "unknown message: :foo"
    end
  end

  @spec initialize_test_state(:ets.tab(), (() -> DateTime.t())) :: Engine.Config.t()
  defp initialize_test_state(table_name_signs, time_fetcher) do
    ^table_name_signs =
      :ets.new(table_name_signs, [:set, :protected, :named_table, read_concurrency: true])

    Engine.Config.Headways.create_table(:test_headways)

    state = %{
      table_name_signs: table_name_signs,
      table_name_headways: :test_headways,
      current_version: nil,
      time_fetcher: time_fetcher
    }

    {:noreply, state} = Engine.Config.handle_info(:update, state)

    state
  end
end
