defmodule Signs.Utilities.ReaderTest do
  use ExUnit.Case, async: true

  alias Content.Message.Custom
  alias Content.Message.Empty
  alias Content.Message.Predictions
  alias Content.Audio.NextTrainCountdown
  alias Signs.Utilities.Reader

  defmodule FakePredictions do
    def for_stop(_stop_id, _direction_id), do: []
    def stopped_at?(_stop_id), do: false
  end

  defmodule FakeUpdater do
    def send_audio(audio_id, audio, priority, timeout) do
      send(self(), {:send_audio, audio_id, audio, priority, timeout})
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
    source_config: %{sources: [@src]},
    current_content_top: %Predictions{destination: :alewife, minutes: 4},
    current_content_bottom: %Predictions{destination: :ashmont, minutes: 3},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    last_departure_engine: FakeDepartures,
    config_engine: Engine.Config,
    alerts_engine: nil,
    sign_updater: FakeUpdater,
    tick_bottom: 1,
    tick_top: 1,
    tick_audit: 240,
    tick_read: 1,
    expiration_seconds: 100,
    read_period_seconds: 100
  }

  describe "read_sign/1" do
    test "when the sign is not on a read interval, does not send next train announcements" do
      sign = %{@sign | tick_read: 100}

      Reader.read_sign(sign)

      refute_received({:send_audio, _id, _, _p, _t})
      refute_received({:send_audio, _id, _, _p, _t})
    end

    test "when the sign is on a read interval, sends next train announcements" do
      sign = %{@sign | tick_read: 0}

      Reader.read_sign(sign)

      assert_received({:send_audio, _id, _, _p, _t})
    end

    test "when the sign is on a read interval, sends a single-line custom announcement" do
      sign = %{
        @sign
        | tick_read: 0,
          current_content_top: %Custom{line: :top, message: "Custom Top"},
          current_content_bottom: %Empty{}
      }

      Reader.read_sign(sign)

      assert_received({:send_audio, _id, [%Content.Audio.Custom{}], _priority, _timeout})
    end
  end

  describe "interrupting_read/1" do
    test "does not send audio when tick read is 0, because it will be read by the read loop" do
      sign = %{@sign | tick_read: 0}

      Reader.interrupting_read(sign)

      refute_received(
        {:send_audio, _id, %NextTrainCountdown{destination: :alewife, minutes: 4, verb: :arrives},
         _p, _t}
      )

      refute_received(
        {:send_audio, _id, %NextTrainCountdown{destination: :ashmont, minutes: 3, verb: :arrives},
         _p, _t}
      )
    end

    test "bumps sign's read loop if interrupted with under 120 seconds to go" do
      sign_under = %{@sign | tick_read: 119, read_period_seconds: 20}
      sign_over = %{@sign | tick_read: 120, read_period_seconds: 20}

      new_sign_under = Reader.interrupting_read(sign_under)
      new_sign_over = Reader.interrupting_read(sign_over)

      assert new_sign_under.tick_read == 139
      assert new_sign_over.tick_read == 120
    end
  end
end
