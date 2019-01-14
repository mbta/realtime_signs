defmodule Engine.ConfigTest do
  use ExUnit.Case

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
      ets_table_name = :config_test

      ^ets_table_name =
        :ets.new(ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

      state = %{
        ets_table_name: ets_table_name,
        current_version: nil,
        time_fetcher: fn -> Timex.to_datetime(~N[2017-07-04 07:00:00], "America/New_York") end
      }

      {:noreply, _state} = Engine.Config.handle_info(:update, state)

      assert Engine.Config.custom_text(:config_test, "custom_text_test") ==
               {"Test message", "Please ignore"}
    end

    test "does not return custom text when it's expired" do
      ets_table_name = :config_test

      ^ets_table_name =
        :ets.new(ets_table_name, [:set, :protected, :named_table, read_concurrency: true])

      state = %{
        ets_table_name: ets_table_name,
        current_version: nil,
        time_fetcher: fn -> Timex.to_datetime(~N[2017-07-04 09:00:00], "America/New_York") end
      }

      {:noreply, _state} = Engine.Config.handle_info(:update, state)

      assert Engine.Config.custom_text(:config_test, "custom_text_test") == nil
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
  end
end
