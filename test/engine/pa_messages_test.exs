defmodule Engine.PaMessagesTest do
  use ExUnit.Case

  @state %{
    pa_message_timers_table: :test_pa_message_timers
  }

  setup_all do
    screenplay_url = Application.get_env(:realtime_signs, :screenplay_url)
    active_pa_messages_path = Application.get_env(:realtime_signs, :active_pa_messages_path)

    Application.put_env(:realtime_signs, :screenplay_url, "https://screenplay-fake.mbtace.com")
    Application.put_env(:realtime_signs, :active_pa_messages_path, "/api/pa-messages/active")

    on_exit(fn ->
      Application.put_env(:realtime_signs, :screenplay_url, screenplay_url)
      Application.put_env(:realtime_signs, :active_pa_messages_path, active_pa_messages_path)
    end)
  end

  setup do
    Application.put_env(:realtime_signs, :active_pa_messages_path, "/api/pa-messages/active")
  end

  describe "handle_info/2 schedule messages" do
    test "Schedules PA messages" do
      Engine.PaMessages.create_table(@state)
      Engine.PaMessages.handle_info(:update, @state)

      pa_ids = Enum.map(:ets.tab2list(:test_pa_message_timers), &elem(&1, 0))

      assert 4 in pa_ids
      assert 5 in pa_ids
    end
  end

  describe "handle_info/2 changes or deletes messages" do
    test "Unschedules inactive PA messages" do
      Engine.PaMessages.create_table(@state)
      Engine.PaMessages.handle_info(:update, @state)
      pa_ids = Enum.map(:ets.tab2list(:test_pa_message_timers), &elem(&1, 0))

      assert 4 in pa_ids
      assert 5 in pa_ids

      Application.put_env(
        :realtime_signs,
        :active_pa_messages_path,
        "/api/pa-messages/no-longer-active"
      )

      Engine.PaMessages.handle_info(:update, @state)
      pa_ids = Enum.map(:ets.tab2list(:test_pa_message_timers), &elem(&1, 0))

      assert 4 not in pa_ids
      assert 5 in pa_ids
    end

    test "Updates timer when interval changes" do
      Engine.PaMessages.create_table(@state)
      Engine.PaMessages.handle_info(:update, @state)

      [{4, {timer_ref_before, pa_message_before}}] = :ets.lookup(:test_pa_message_timers, 4)

      Application.put_env(
        :realtime_signs,
        :active_pa_messages_path,
        "/api/pa-messages/changed-interval"
      )

      Engine.PaMessages.handle_info(:update, @state)

      [{4, {timer_ref_after, pa_message_after}}] = :ets.lookup(:test_pa_message_timers, 4)

      assert timer_ref_before != timer_ref_after
      assert Process.read_timer(timer_ref_before) == false
      assert pa_message_before.interval_in_ms < pa_message_after.interval_in_ms
    end
  end
end
