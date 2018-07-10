defmodule Signs.Utilities.UpdaterTest do
  use ExUnit.Case, async: true

  alias Content.Message.Predictions, as: P
  alias Signs.Utilities.Updater

  defmodule FakePredictions do
    def for_stop(_stop_id, _direction_id), do: []
    def stopped_at?(_stop_id), do: false
  end

  defmodule FakeUpdater do
    def update_single_line(id, line_no, msg, duration, start) do
      send(self(), {:update_single_line, id, line_no, msg, duration, start})
    end

    def update_sign(id, top_msg, bottom_msg, duration, start) do
      send(self(), {:update_sign, id, top_msg, bottom_msg, duration, start})
    end

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
    source_config: {[], []},
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

  describe "update_sign/3" do
    test "doesn't do anything if both lines are the same" do
      same_top = {@src, %P{headsign: "Alewife", minutes: 4}}
      same_bottom = {@src, %P{headsign: "Ashmont", minutes: 3}}

      sign = Updater.update_sign(@sign, same_top, same_bottom)

      refute_received({:send_audio, _, _, _, _})
      refute_received({:update_single_line, _, _, _, _, _})
      refute_received({:update_sign, _, _, _ , _, _})
      assert sign.tick_top == 1
      assert sign.tick_bottom == 1
    end

    test "changes the top line if necessary" do
      diff_top = {@src, %P{headsign: "Alewife", minutes: 3}}
      same_bottom = {@src, %P{headsign: "Ashmont", minutes: 3}}

      sign = Updater.update_sign(@sign, diff_top, same_bottom)

      refute_received({:send_audio, _, _, _, _})
      assert_received({:update_single_line, _id, "1", %P{minutes: 3}, _dur, _start})
      refute_received({:update_sign, _, _, _ , _, _})
      assert sign.tick_top == 100
      assert sign.tick_bottom == 1
    end

    test "changes the bottom line if necessary" do
      same_top = {@src, %P{headsign: "Alewife", minutes: 4}}
      diff_bottom = {@src, %P{headsign: "Ashmont", minutes: 2}}

      sign = Updater.update_sign(@sign, same_top, diff_bottom)

      refute_received({:send_audio, _, _, _, _})
      assert_received({:update_single_line, _id, "2", %P{minutes: 2}, _dur, _start})
      refute_received({:update_sign, _, _, _ , _, _})
      assert sign.tick_top == 1
      assert sign.tick_bottom == 100
    end

    test "changes both lines if necessary" do
      diff_top = {@src, %P{headsign: "Alewife", minutes: 3}}
      diff_bottom = {@src, %P{headsign: "Ashmont", minutes: 2}}

      sign = Updater.update_sign(@sign, diff_top, diff_bottom)

      refute_received({:send_audio, _, _, _, _})
      refute_received({:update_single_line, _, _, _, _, _})
      assert_received({:update_sign, _id, %P{minutes: 3}, %P{minutes: 2} , _dur, _start})
      assert sign.tick_top == 100
      assert sign.tick_bottom == 100
    end

    test "announces arriving if announce_arriving? is true" do
      src = %{@src | announce_arriving?: true}
      diff_top = {src, %P{headsign: "Alewife", minutes: :arriving}}
      diff_bottom = {src, %P{headsign: "Ashmont", minutes: :arriving}}

      sign = Updater.update_sign(@sign, diff_top, diff_bottom)

      assert_received({:send_audio, _, %Content.Audio.TrainIsArriving{destination: :ashmont}, _, _})
      assert sign.tick_top == 100
      assert sign.tick_bottom == 100
    end
  end
end
