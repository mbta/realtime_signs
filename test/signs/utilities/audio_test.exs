defmodule AudioTest do
  use ExUnit.Case

  @fake_time DateTime.new!(~D[2023-01-01], ~T[12:00:00], "America/New_York")
  def fake_time_fn, do: @fake_time

  describe "handle_pa_message_play/2" do
    setup do
      pa_message = %PaMessages.PaMessage{
        id: 1,
        visual_text: "A PA Message",
        audio_text: "A PA Message",
        interval_in_ms: 120_000,
        priority: 2
      }

      realtime_sign = %Signs.Realtime{
        id: "sign_id",
        pa_ess_loc: "TEST",
        scu_id: "TESTSCU001",
        text_zone: "x",
        audio_zones: ["x"],
        source_config: %{
          terminal?: false,
          sources: [
            %Signs.Utilities.SourceConfig{
              stop_id: "1",
              direction_id: 0,
              routes: ["Red"],
              announce_arriving?: true,
              announce_boarding?: false
            }
          ],
          headway_group: "headway_group",
          headway_destination: :southbound
        },
        current_content_top: "Southbound trains",
        current_content_bottom: "Every 11 to 13 min",
        current_time_fn: &Signs.RealtimeTest.fake_time_fn/0,
        last_update: @fake_time,
        tick_read: 1,
        read_period_seconds: 100,
        pa_message_plays: %{},
        last_message_log_time: @fake_time
      }

      bus_sign = %Signs.Bus{
        id: "auto_sign",
        pa_ess_loc: "ABCD",
        scu_id: "ABCDSCU001",
        text_zone: "m",
        audio_zones: ["m"],
        max_minutes: 60,
        configs: nil,
        top_configs: nil,
        bottom_configs: nil,
        extra_audio_configs: nil,
        chelsea_bridge: nil,
        read_loop_interval: 360,
        read_loop_offset: 30,
        prev_predictions: [],
        prev_bridge_status: nil,
        current_messages: {nil, nil},
        last_update: nil,
        last_read_time: Timex.shift(Timex.now(), minutes: -10),
        pa_message_plays: %{}
      }

      %{
        pa_message: pa_message,
        realtime_sign: realtime_sign,
        bus_sign: bus_sign
      }
    end

    test "returns true for realtime sign if no prior plays", %{
      pa_message: pa_message,
      realtime_sign: realtime_sign
    } do
      assert {_, true} =
               Signs.Utilities.Audio.handle_pa_message_play(pa_message, realtime_sign, false)
    end

    test "returns true for bus sign if no prior plays", %{
      pa_message: pa_message,
      bus_sign: bus_sign
    } do
      assert {_, true} = Signs.Utilities.Audio.handle_pa_message_play(pa_message, bus_sign)
    end

    test "returns true for realtime sign if interval has passed", %{
      pa_message: pa_message,
      realtime_sign: realtime_sign
    } do
      realtime_sign = %{realtime_sign | pa_message_plays: %{1 => ~U[2024-06-10 12:00:00.000Z]}}

      assert {_, true} =
               Signs.Utilities.Audio.handle_pa_message_play(pa_message, realtime_sign, false)
    end

    test "returns true for bus sign if interval has passed", %{
      pa_message: pa_message,
      bus_sign: bus_sign
    } do
      bus_sign = %{bus_sign | pa_message_plays: %{1 => ~U[2024-06-10 12:00:00.000Z]}}

      assert {_, true} = Signs.Utilities.Audio.handle_pa_message_play(pa_message, bus_sign)
    end

    test "returns false for realtime sign if the interval has not passed", %{
      pa_message: pa_message,
      realtime_sign: realtime_sign
    } do
      realtime_sign = %{realtime_sign | pa_message_plays: %{1 => DateTime.utc_now()}}

      assert {_, false} =
               Signs.Utilities.Audio.handle_pa_message_play(pa_message, realtime_sign, false)
    end

    test "returns false for bus sign if the interval has not passed", %{
      pa_message: pa_message,
      bus_sign: bus_sign
    } do
      bus_sign = %{bus_sign | pa_message_plays: %{1 => DateTime.utc_now()}}

      assert {_, false} = Signs.Utilities.Audio.handle_pa_message_play(pa_message, bus_sign)
    end

    test "returns false for realtime sign in overnight mode for non-emergency messages", %{
      pa_message: pa_message,
      realtime_sign: realtime_sign
    } do
      assert {_, false} =
               Signs.Utilities.Audio.handle_pa_message_play(pa_message, realtime_sign, true)
    end

    test "returns true for realtime sign in overnight mode for emergency messages", %{
      pa_message: pa_message,
      realtime_sign: realtime_sign
    } do
      pa_message = %{pa_message | priority: 1}

      assert {_, true} =
               Signs.Utilities.Audio.handle_pa_message_play(pa_message, realtime_sign, true)
    end
  end
end
