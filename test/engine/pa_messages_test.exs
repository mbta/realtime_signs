defmodule Engine.PaMessagesTest do
  alias PaMessages.PaMessage
  use ExUnit.Case

  @state %{
    pa_messages_last_sent: %{}
  }

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
    Application.put_env(
      :realtime_signs,
      :active_pa_messages_path,
      "/api/pa-messages/active"
    )
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
          4 => {%PaMessage{}, last_played},
          5 => {%PaMessage{}, last_played}
        }
      }

      {:noreply, state} = Engine.PaMessages.handle_info(:update, state)
      assert last_played == Map.get(state.pa_messages_last_sent, 4) |> elem(1)
      assert last_played == Map.get(state.pa_messages_last_sent, 5) |> elem(1)
    end

    test "Ignores inactive PA messages" do
      {:noreply, state} = Engine.PaMessages.handle_info(:update, @state)
      pa_ids = Map.keys(state.pa_messages_last_sent)

      assert 4 in pa_ids
      assert 5 in pa_ids

      Application.put_env(
        :realtime_signs,
        :active_pa_messages_path,
        "/api/pa-messages/no-longer-active"
      )

      {:noreply, state} = Engine.PaMessages.handle_info(:update, @state)
      pa_ids = Map.keys(state.pa_messages_last_sent)

      refute 4 in pa_ids
      assert 5 in pa_ids
    end

    test "Plays PA Message when interval is edited to be shorter" do
      last_play = DateTime.utc_now() |> DateTime.add(-2, :minute)
      state = %{pa_messages_last_sent: %{5 => {%PaMessage{}, last_play}}}

      Application.put_env(
        :realtime_signs,
        :active_pa_messages_path,
        "/api/pa-messages/changed-interval"
      )

      {:noreply, state} = Engine.PaMessages.handle_info(:update, state)
      refute last_play == Map.get(state.pa_messages_last_sent, 5) |> elem(1)
    end
  end
end
