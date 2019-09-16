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
    def update_single_line(id, line_no, msg, duration, start) do
      send(self(), {:update_single_line, id, line_no, msg, duration, start})
    end

    def update_sign(id, top_msg, bottom_msg, duration, start) do
      send(self(), {:update_sign, id, top_msg, bottom_msg, duration, start})
    end

    def send_audio(audio_id, audio, priority, timeout) do
      send(self(), {:send_audio, audio_id, audio, priority, timeout})
    end
  end

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    headway_direction_name: "Southbound",
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
    source_config: {[]},
    current_content_top: {@src, %P{headsign: "Alewife", minutes: 4}},
    current_content_bottom: {@src, %P{headsign: "Ashmont", minutes: 3}},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    last_departure_engine: FakeDepartures,
    alerts_engine: nil,
    bridge_engine: nil,
    sign_updater: FakeUpdater,
    tick_bottom: 1,
    tick_top: 1,
    tick_audit: 240,
    tick_read: 60,
    expiration_seconds: 100,
    read_period_seconds: 100
  }

  describe "update_sign/3" do
    test "doesn't do anything if both lines are the same" do
      same_top = {@src, %P{headsign: "Alewife", minutes: 4}}
      same_bottom = {@src, %P{headsign: "Ashmont", minutes: 3}}

      sign = Updater.update_sign(@sign, same_top, same_bottom)

      refute_received({:send_audio, _, _, _, _})
      refute_received({:update_single_line, _, _, _, _, _})
      refute_received({:update_sign, _, _, _, _, _})
      assert sign.tick_top == 1
      assert sign.tick_bottom == 1
    end

    test "changes the top line if necessary" do
      diff_top = {@src, %P{headsign: "Alewife", minutes: 3}}
      same_bottom = {@src, %P{headsign: "Ashmont", minutes: 3}}

      sign = Updater.update_sign(@sign, diff_top, same_bottom)

      refute_received({:send_audio, _, _, _, _})
      assert_received({:update_single_line, _id, "1", %P{minutes: 3}, _dur, _start})
      refute_received({:update_sign, _, _, _, _, _})
      assert sign.tick_top == 100
      assert sign.tick_bottom == 1
    end

    test "does not change top line if it would be a count up from ARR to approaching" do
      sign = %{@sign | current_content_top: {@src, %P{headsign: "Alewife", minutes: :arriving}}}
      diff_top = {@src, %P{headsign: "Alewife", minutes: :approaching}}
      same_bottom = {@src, %P{headsign: "Ashmont", minutes: 3}}

      Updater.update_sign(sign, diff_top, same_bottom)

      refute_received({:update_single_line, _id, "1", %P{minutes: :approaching}, _dur, _start})
    end

    test "does not change the top line if it would be a count up from approaching to 1 min" do
      sign = %{
        @sign
        | current_content_top: {@src, %P{headsign: "Alewife", minutes: :approaching}}
      }

      diff_top = {@src, %P{headsign: "Alewife", minutes: 1}}
      same_bottom = {@src, %P{headsign: "Ashmont", minutes: 3}}

      Updater.update_sign(sign, diff_top, same_bottom)

      refute_received({:update_single_line, _id, "1", %P{minutes: 1}, _dur, _start})
    end

    test "does not change top line if it would be a count up from 3 min to 4 min" do
      sign = %{@sign | current_content_top: {@src, %P{headsign: "Alewife", minutes: 3}}}
      diff_top = {@src, %P{headsign: "Alewife", minutes: 4}}
      same_bottom = {@src, %P{headsign: "Ashmont", minutes: 3}}

      Updater.update_sign(sign, diff_top, same_bottom)

      refute_received({:update_single_line, _id, "1", %P{minutes: 4}, _dur, _start})
    end

    test "does not change bottom line if it would be a count up from ARR to approaching" do
      sign = %{
        @sign
        | current_content_bottom: {@src, %P{headsign: "Ashmont", minutes: :arriving}}
      }

      same_top = {@src, %P{headsign: "Alewife", minutes: 4}}
      diff_bottom = {@src, %P{headsign: "Ashmont", minutes: :approaching}}

      Updater.update_sign(sign, same_top, diff_bottom)

      refute_received({:update_single_line, _id, "2", %P{minutes: :approaching}, _dur, _start})
    end

    test "changes the bottom line if necessary" do
      same_top = {@src, %P{headsign: "Alewife", minutes: 4}}
      diff_bottom = {@src, %P{headsign: "Ashmont", minutes: 2}}

      sign = Updater.update_sign(@sign, same_top, diff_bottom)

      refute_received({:send_audio, _, _, _, _})
      assert_received({:update_single_line, _id, "2", %P{minutes: 2}, _dur, _start})
      refute_received({:update_sign, _, _, _, _, _})
      assert sign.tick_top == 1
      assert sign.tick_bottom == 100
    end

    test "changes both lines if necessary" do
      diff_top = {@src, %P{headsign: "Alewife", minutes: 3}}
      diff_bottom = {@src, %P{headsign: "Ashmont", minutes: 2}}

      sign = Updater.update_sign(@sign, diff_top, diff_bottom)

      refute_received({:update_single_line, _, _, _, _, _})
      assert_received({:update_sign, _id, %P{minutes: 3}, %P{minutes: 2}, _dur, _start})
      assert sign.tick_top == 100
      assert sign.tick_bottom == 100
    end

    test "doesn't do an interrupting read if new top is same as old bottom and is a boarding message" do
      src = %{@src | announce_boarding?: true}

      sign = %{
        @sign
        | current_content_top: {src, %P{headsign: "Alewife", minutes: :boarding}},
          current_content_bottom: {src, %P{headsign: "Ashmont", minutes: :boarding}}
      }

      diff_top = {src, %P{headsign: "Ashmont", minutes: :boarding}}
      diff_bottom = {src, %P{headsign: "Alewife", minutes: 19}}
      Updater.update_sign(sign, diff_top, diff_bottom)
      refute_received({:send_audio, _, _, _, _})
    end

    test "logs when stopped train message turns on" do
      diff_top = {@src, %Content.Message.StoppedTrain{headsign: "Alewife", stops_away: 2}}
      same_bottom = @sign.current_content_bottom

      initial_tick_read = 10
      read_period_seconds = 100

      sign = %{@sign | tick_read: initial_tick_read, read_period_seconds: read_period_seconds}

      log =
        capture_log([level: :info], fn ->
          Updater.update_sign(sign, diff_top, same_bottom)
        end)

      assert log =~ "sign_id=sign_id line=top status=on"
    end

    test "logs when stopped train message turns off" do
      new_top = {@src, %P{headsign: "Alewife", minutes: 4}}
      new_bottom = {@src, %P{headsign: "Alewife", minutes: 4}}

      initial_tick_read = 10
      read_period_seconds = 100

      sign = %{
        @sign
        | current_content_top:
            {@src, %Content.Message.StoppedTrain{headsign: "Alewife", stops_away: 2}},
          current_content_bottom:
            {@src, %Content.Message.StoppedTrain{headsign: "Alewife", stops_away: 2}},
          tick_read: initial_tick_read,
          read_period_seconds: read_period_seconds
      }

      log =
        capture_log([level: :info], fn ->
          Updater.update_sign(sign, new_top, new_bottom)
        end)

      assert log =~ "sign_id=sign_id line=top status=off"
      assert log =~ "sign_id=sign_id line=bottom status=off"
    end

    test "logs when stopped train message changes from zero to non-zero stops away" do
      diff_top = {@src, %Content.Message.StoppedTrain{headsign: "Alewife", stops_away: 2}}
      same_bottom = {@src, %Content.Message.StoppedTrain{headsign: "Ashmont", stops_away: 2}}

      initial_tick_read = 10
      read_period_seconds = 100

      sign = %{
        @sign
        | current_content_top:
            {@src, %Content.Message.StoppedTrain{headsign: "Alewife", stops_away: 0}},
          current_content_bottom:
            {@src, %Content.Message.StoppedTrain{headsign: "Ashmont", stops_away: 0}},
          tick_read: initial_tick_read,
          read_period_seconds: read_period_seconds
      }

      log =
        capture_log([level: :info], fn ->
          Updater.update_sign(sign, diff_top, same_bottom)
        end)

      assert log =~ "sign_id=sign_id line=top status=on"
      assert log =~ "sign_id=sign_id line=bottom status=on"
    end

    test "logs when stopped train message changes from non-zero to zero stops away" do
      diff_top = {@src, %Content.Message.StoppedTrain{headsign: "Alewife", stops_away: 0}}
      same_bottom = {@src, %Content.Message.StoppedTrain{headsign: "Ashmont", stops_away: 0}}

      initial_tick_read = 10
      read_period_seconds = 100

      sign = %{
        @sign
        | current_content_top:
            {@src, %Content.Message.StoppedTrain{headsign: "Alewife", stops_away: 2}},
          current_content_bottom:
            {@src, %Content.Message.StoppedTrain{headsign: "Ashmont", stops_away: 2}},
          tick_read: initial_tick_read,
          read_period_seconds: read_period_seconds
      }

      log =
        capture_log([level: :info], fn ->
          Updater.update_sign(sign, diff_top, same_bottom)
        end)

      assert log =~ "sign_id=sign_id line=top status=off"
      assert log =~ "sign_id=sign_id line=bottom status=off"
    end
  end
end
