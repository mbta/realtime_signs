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
