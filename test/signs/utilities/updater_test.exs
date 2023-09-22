defmodule Signs.Utilities.UpdaterTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Content.Message.Predictions, as: P
  alias Signs.Utilities.Updater

  defmodule FakePredictions do
    def for_stop(_stop_id, _direction_id), do: []
    def stopped_at?(_stop_id), do: false
  end

  defmodule FakeUpdater do
    def update_sign(id, top_msg, bottom_msg, duration, start, sign_id) do
      send(self(), {:update_sign, id, top_msg, bottom_msg, duration, start, sign_id})
    end

    def send_audio(audio_id, audio, priority, timeout, sign_id) do
      send(self(), {:send_audio, audio_id, audio, priority, timeout, sign_id})
    end
  end

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    direction_id: 0,
    platform: nil,
    terminal?: false,
    announce_arriving?: false,
    announce_boarding?: false
  }

  @sign %Signs.Realtime{
    id: "sign_id",
    text_id: {"TEST", "x"},
    audio_id: {"TEST", ["x"]},
    source_config: %{sources: []},
    current_content_top: %P{destination: :alewife, minutes: 4},
    current_content_bottom: %P{destination: :ashmont, minutes: 3},
    location_engine: Engine.Locations.Mock,
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    config_engine: Engine.Config,
    alerts_engine: nil,
    current_time_fn: nil,
    sign_updater: FakeUpdater,
    last_update: Timex.now(),
    tick_read: 60,
    read_period_seconds: 100
  }

  describe "update_sign/3" do
    test "doesn't do anything if both lines are the same" do
      same_top = %P{destination: :alewife, minutes: 4}
      same_bottom = %P{destination: :ashmont, minutes: 3}

      sign = Updater.update_sign(@sign, same_top, same_bottom, Timex.now())

      refute_received({:send_audio, _, _, _, _, _})
      refute_received({:update_sign, _, _, _, _, _, _})
      assert sign.last_update == @sign.last_update
    end

    test "changes both lines if necessary" do
      now = Timex.now()
      diff_top = %P{destination: :alewife, minutes: 3}
      diff_bottom = %P{destination: :ashmont, minutes: 2}

      sign = Updater.update_sign(@sign, diff_top, diff_bottom, now)

      assert_received({:update_sign, _id, %P{minutes: 3}, %P{minutes: 2}, _dur, _start, _sign_id})
      assert sign.last_update == now
    end

    test "doesn't do an interrupting read if new top is same as old bottom and is a boarding message" do
      src = %{@src | announce_boarding?: true}

      sign = %{
        @sign
        | current_content_top: {src, %P{destination: :alewife, minutes: :boarding}},
          current_content_bottom: {src, %P{destination: :ashmont, minutes: :boarding}}
      }

      diff_top = {src, %P{destination: :ashmont, minutes: :boarding}}
      diff_bottom = {src, %P{destination: :alewife, minutes: 19}}
      Updater.update_sign(sign, diff_top, diff_bottom, Timex.now())
      refute_received({:send_audio, _, _, _, _, _})
    end
  end
end
