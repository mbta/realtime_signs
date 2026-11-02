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
    stub(PaEss.Updater.Mock, :play_message, fn [], _, _, _ -> nil end)
    stub_pa_messages("active")
  end

  describe "handle_info/2" do
    test "Plays PA messages" do
      {:noreply, state} = Engine.PaMessages.handle_info(:update, @state)

      pa_ids = Map.keys(state.pa_messages_last_sent)

      assert 4 in pa_ids
      assert 5 in pa_ids
    end

    test "Doesn't play PA Message if less than interval has passed" do
      last_played = DateTime.utc_now() |> DateTime.add(-1, :minute)

      state = %{
        pa_messages_last_sent: %{
          4 => last_played,
          5 => last_played
        }
      }

      {:noreply, state} = Engine.PaMessages.handle_info(:update, state)
      assert last_played == Map.get(state.pa_messages_last_sent, 4)
      assert last_played == Map.get(state.pa_messages_last_sent, 5)
    end

    test "Ignores inactive PA messages" do
      {:noreply, state} = Engine.PaMessages.handle_info(:update, @state)
      pa_ids = Map.keys(state.pa_messages_last_sent)

      assert 4 in pa_ids
      assert 5 in pa_ids

      stub_pa_messages("no-longer-active")

      {:noreply, state} = Engine.PaMessages.handle_info(:update, @state)
      pa_ids = Map.keys(state.pa_messages_last_sent)

      refute 4 in pa_ids
      assert 5 in pa_ids
    end

    test "Plays PA Message when interval is edited to be shorter" do
      last_play = DateTime.utc_now() |> DateTime.add(-2, :minute)
      state = %{pa_messages_last_sent: %{5 => last_play}}

      stub_pa_messages("changed-interval")

      {:noreply, state} = Engine.PaMessages.handle_info(:update, state)
      refute last_play == Map.get(state.pa_messages_last_sent, 5)
    end

    test "Prioritizes all emergency messages" do
      stub_pa_messages("priority-high")
      {:noreply, state} = Engine.PaMessages.handle_info(:update, @state)
      assert [1, 2] == Map.keys(state.pa_messages_last_sent) |> Enum.sort()
    end

    test "Plays one disruption announcement" do
      stub_pa_messages("priority-mid")
      {:noreply, state} = Engine.PaMessages.handle_info(:update, @state)
      assert [3] == Map.keys(state.pa_messages_last_sent) |> Enum.sort()
    end

    test "Plays all PSA messages" do
      stub_pa_messages("priority-low")
      {:noreply, state} = Engine.PaMessages.handle_info(:update, @state)
      assert [6, 7] == Map.keys(state.pa_messages_last_sent) |> Enum.sort()
    end
  end
end
