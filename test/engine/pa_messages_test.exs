defmodule Engine.PaMessagesTest do
  use ExUnit.Case
  import Mox

  @state %{
    pa_messages_last_sent: %{}
  }

  defp stub_pa_messages(token) do
    Application.put_env(:realtime_signs, :active_pa_messages_path, "/api/pa-messages/#{token}")
  end

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
    stub(Engine.PaMessages.Mock, :play_pa_message, fn _, _ ->
      {%Signs.Realtime{
         id: "east",
         pa_ess_loc: "TEST",
         scu_id: "TESTSCU001",
         text_zone: "e",
         audio_zones: ["e"],
         configs: [],
         current_content_top: "",
         current_content_bottom: "",
         last_update: nil,
         tick_read: 0,
         read_period_seconds: 180,
         last_message_log_time: nil
       }, true}
    end)

    stub_pa_messages("active")
  end

  describe "handle_info/2" do
    test "Plays PA messages" do
      expect_pa_message("PA message 1")
      expect_pa_message("PA message 2")
      last_played = DateTime.utc_now() |> DateTime.add(-3, :minute)

      {:noreply, _state} =
        Engine.PaMessages.handle_info(:update, %{pa_messages_last_sent: %{1 => last_played}})
    end

    test "Doesn't play PA Message if less than interval has passed" do
      last_played = DateTime.utc_now() |> DateTime.add(-1, :minute)

      {:noreply, _state} =
        Engine.PaMessages.handle_info(:update, %{
          pa_messages_last_sent: %{1 => last_played, 2 => last_played}
        })
    end

    test "Prioritizes all emergency messages" do
      stub_pa_messages("priority-high")
      expect_pa_message("Emergency message 1")
      expect_pa_message("Emergency message 2")
      {:noreply, _state} = Engine.PaMessages.handle_info(:update, @state)
    end

    test "Prioritizes one disruption announcement" do
      stub_pa_messages("priority-mid")
      expect_pa_message("Service message 1")
      {:noreply, _state} = Engine.PaMessages.handle_info(:update, @state)
    end

    test "Plays all PSA messages if no higher priority" do
      stub_pa_messages("priority-low")
      expect_pa_message("PSA message 1")
      expect_pa_message("PSA message 2")
      {:noreply, _state} = Engine.PaMessages.handle_info(:update, @state)
    end
  end

  defp expect_pa_message(text) do
    expect(PaEss.Updater.Mock, :play_message, fn _, [{^text, ^text}], _, _ -> :ok end)
  end
end
