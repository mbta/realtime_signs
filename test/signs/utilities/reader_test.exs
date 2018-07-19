defmodule Signs.Utilities.ReaderTest do
  use ExUnit.Case, async: true

  alias Content.Message.Predictions, as: P
  alias Content.Audio.NextTrainCountdown, as: A
  alias Signs.Utilities.Reader

  defmodule FakePredictions do
    def for_stop(_stop_id, _direction_id), do: []
    def stopped_at?(_stop_id), do: false
  end

  defmodule FakeUpdater do
    def send_audio(id, audio, priority, timeout) do
      send(self(), {:send_audio, id, audio, priority, timeout})
    end
  end

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    direction_id: 0,
    platform: nil,
    terminal?: false,
    announce_arriving?: false,
  }

  @sign %Signs.Realtime{
    id: "sign_id",
    pa_ess_id: {"TEST", "x"},
    source_config: {[@src]},
    current_content_top: {@src, %P{headsign: "Alewife", minutes: 4}},
    current_content_bottom: {@src, %P{headsign: "Ashmont", minutes: 3}},
    prediction_engine: FakePredictions,
    sign_updater: FakeUpdater,
    tick_bottom: 1,
    tick_top: 1,
    tick_read: 1,
    expiration_seconds: 100,
    read_period_seconds: 100,
  }

  describe "read_sign/1" do
    test "sends audio for top and bottom when headsigns are different" do
      sign = %{@sign | tick_read: 0}

      sign = Reader.read_sign(sign)

      assert_received({:send_audio, _id, %A{destination: :alewife, minutes: 4, verb: :arrives}, _p, _t})
      assert_received({:send_audio, _id, %A{destination: :ashmont, minutes: 3, verb: :arrives}, _p, _t})
      assert sign.tick_read == 100
    end

    test "sends audio only for top, if bottom has same headsign" do
      sign = %{@sign | tick_read: 0, current_content_bottom: {@src, %P{headsign: "Alewife", minutes: 3}}}

      sign = Reader.read_sign(sign)

      assert_received({:send_audio, _id, %A{destination: :alewife, minutes: 4, verb: :arrives}, _p, _t})
      refute_received({:send_audio, _id, %A{destination: :alewife, minutes: 3, verb: :arrives}, _p, _t})
      assert sign.tick_read == 100
    end

    test "does not send audio if the tick count isn't 0" do
      sign = %{@sign | tick_read: 37}

      sign = Reader.read_sign(sign)

      refute_received({:send_audio, _id, _audio, _p, _t})
      assert sign.tick_read == 37
    end

    test "uses 'departs' if it's for a terminal" do
      src = %{@src | terminal?: true}
      sign = %{@sign | tick_read: 0, current_content_top: {src, %P{headsign: "Alewife", minutes: 4}}}

      sign = Reader.read_sign(sign)

      assert_received({:send_audio, _id, %A{destination: :alewife, verb: :departs}, _p, _t})
      assert_received({:send_audio, _id, %A{destination: :ashmont, verb: :arrives}, _p, _t})
      assert sign.tick_read == 100
    end
  end
end
