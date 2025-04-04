defmodule Engine.ConfigTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  describe "sign_config/2" do
    test "is the provided default value when the sign is unspecified" do
      state = initialize_test_state(%{})

      assert Engine.Config.sign_config(state.table_name_signs, "unspecified_sign", :headway) ==
               :headway
    end

    test "returns custom text when it's not expired" do
      state =
        initialize_test_state(%{
          table_name_signs: :config_test_non_expired,
          time_fetcher: fn ->
            Timex.to_datetime(~N[2017-07-04 07:00:00], "America/New_York")
          end
        })

      assert Engine.Config.sign_config(state.table_name_signs, "custom_text_test", :off) ==
               {:static_text, {"Test message", "Please ignore"}}
    end

    test "does not return custom text when it's expired" do
      state =
        initialize_test_state(%{
          table_name_signs: :config_test_expired,
          time_fetcher: fn ->
            Timex.to_datetime(~N[2017-07-04 09:00:00], "America/New_York")
          end
        })

      assert Engine.Config.sign_config(state.table_name_signs, "custom_text_test", :off) == :auto
    end
  end

  describe "handle_info/2" do
    test "does not update config when it is unchanged" do
      state = initialize_test_state(%{current_version: "unchanged"})
      assert state[:current_version] == "unchanged"
    end

    test "handles new format of config" do
      initialize_test_state(%{table_name_signs: :test_new_format, current_version: "new_format"})

      assert Engine.Config.sign_config(:test_new_format, "some_custom_sign", :off) ==
               {:static_text, {"custom", ""}}
    end

    test "handles a config with multi-sign headways" do
      initialize_test_state(%{
        table_name_headways: :test_group_headways,
        current_version: "headway_config"
      })

      test_time = DateTime.from_naive!(~N[2020-03-20 08:00:00], "America/New_York")

      assert %Engine.Config.Headway{range_low: 8, range_high: 10} =
               Engine.Config.headway_config(
                 :test_group_headways,
                 "custom_headway",
                 test_time
               )
    end

    test "correctly loads config for a sign with a mode of \"off\"" do
      initialize_test_state(%{table_name_signs: :config_test_off})

      assert Engine.Config.sign_config(:config_test_off, "off_test", :auto) == :off
    end

    test "correctly loads config for a sign with a mode of \"auto\"" do
      initialize_test_state(%{table_name_signs: :config_test_auto})

      assert Engine.Config.sign_config(:config_test_auto, "auto_test", :off) == :auto
    end

    test "correctly loads config for a sign with a mode of \"headway\"" do
      initialize_test_state(%{table_name_signs: :config_test_headway})

      assert Engine.Config.sign_config(:config_test_headway, "headway_test", :off) == :headway
    end

    test "loads chelsea bridge config" do
      initialize_test_state(%{
        table_name_chelsea_bridge: :bridge_off,
        current_version: "new_format"
      })

      assert Engine.Config.chelsea_bridge_config(:bridge_off) == :off
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

  @spec initialize_test_state(map()) :: Engine.Config.t()
  defp initialize_test_state(overrides) do
    state =
      Map.merge(
        %{
          table_name_signs: :test_signs,
          table_name_headways: :test_headways,
          table_name_chelsea_bridge: :test_chelsea_bridge,
          table_name_scus_migrated: :test_scus_migrated,
          current_version: nil,
          time_fetcher: &DateTime.utc_now/0
        },
        overrides
      )

    Engine.Config.create_tables(state)
    {:noreply, state} = Engine.Config.handle_info(:update, state)
    state
  end
end
