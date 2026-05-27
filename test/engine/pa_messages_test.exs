defmodule Engine.PaMessagesTest do
  use ExUnit.Case
  import Mox

  setup_all do
    screenplay_base_url = Application.get_env(:realtime_signs, :screenplay_base_url)
    active_pa_messages_path = Application.get_env(:realtime_signs, :active_pa_messages_path)

    Application.put_env(
      :realtime_signs,
      :screenplay_base_url,
      "https://screenplay-fake.mbtace.com"
    )

    on_exit(fn ->
      Application.put_env(:realtime_signs, :screenplay_base_url, screenplay_base_url)
      Application.put_env(:realtime_signs, :active_pa_messages_path, active_pa_messages_path)
    end)
  end

  setup do
    stub(PaEss.Updater.Mock, :play_message, fn [], _, _, _, _ -> nil end)

    Application.put_env(
      :realtime_signs,
      :active_pa_messages_path,
      "/api/pa-messages/active"
    )

    table = :ets.new(:pa_messages_test, read_concurrency: true)
    %{table: table}
  end

  describe "handle_info/2" do
    test "fetches PA messages", %{table: table} do
      Engine.PaMessages.handle_info(:update, %{table: table})

      assert [%{id: 4}] = Engine.PaMessages.for_sign("1", table)
      assert [%{id: 5}] = Engine.PaMessages.for_sign("2", table)
    end

    test "Ignores inactive PA messages", %{table: table} do
      Engine.PaMessages.handle_info(:update, %{table: table})

      assert [%{id: 4}] = Engine.PaMessages.for_sign("1", table)
      assert [%{id: 5}] = Engine.PaMessages.for_sign("2", table)

      Application.put_env(
        :realtime_signs,
        :active_pa_messages_path,
        "/api/pa-messages/no-longer-active"
      )

      Engine.PaMessages.handle_info(:update, %{table: table})

      assert [] = Engine.PaMessages.for_sign("1", table)
      assert [%{id: 5}] = Engine.PaMessages.for_sign("2", table)
    end
  end
end
