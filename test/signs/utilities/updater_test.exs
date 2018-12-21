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

    def send_audio(id, audio, priority, timeout) do
      send(self(), {:send_audio, id, audio, priority, timeout})
    end
  end

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    headway_direction_name: "Southbound",
    direction_id: 0,
    platform: nil,
    terminal?: false,
    announce_arriving?: false
  }

  @sign %Signs.Realtime{
    id: "sign_id",
    pa_ess_id: {"TEST", "x"},
    source_config: {[]},
    current_content_top: {@src, %P{headsign: "Alewife", minutes: 4}},
    current_content_bottom: {@src, %P{headsign: "Ashmont", minutes: 3}},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    sign_updater: FakeUpdater,
    tick_bottom: 1,
    tick_top: 1,
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

    test "does not change top line if it would be a count up from ARR to 1 min" do
      sign = %{@sign | current_content_top: {@src, %P{headsign: "Alewife", minutes: :arriving}}}
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

    test "does not change bottom line if it would be a count up from ARR to 1 min" do
      sign = %{
        @sign
        | current_content_bottom: {@src, %P{headsign: "Ashmont", minutes: :arriving}}
      }

      same_top = {@src, %P{headsign: "Alewife", minutes: 4}}
      diff_bottom = {@src, %P{headsign: "Ashmont", minutes: 1}}

      Updater.update_sign(sign, same_top, diff_bottom)

      refute_received({:update_single_line, _id, "2", %P{minutes: 1}, _dur, _start})
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

      refute_received({:send_audio, _, _, _, _})
      refute_received({:update_single_line, _, _, _, _, _})
      assert_received({:update_sign, _id, %P{minutes: 3}, %P{minutes: 2}, _dur, _start})
      assert sign.tick_top == 100
      assert sign.tick_bottom == 100
    end

    test "announces arriving if announce_arriving? is true" do
      src = %{@src | announce_arriving?: true}
      diff_top = {src, %P{headsign: "Alewife", minutes: :arriving}}
      diff_bottom = {src, %P{headsign: "Ashmont", minutes: :arriving}}

      sign = Updater.update_sign(@sign, diff_top, diff_bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _, _}
      )

      assert sign.tick_top == 100
      assert sign.tick_bottom == 100
    end

    test "does not announce arrival if single-source sign and the bottom line has changed" do
      single_source_sign = %{@sign | source_config: {[]}, tick_read: 40}
      src = %{@src | announce_arriving?: true}
      same_top = @sign.current_content_top
      diff_bottom = {src, %P{headsign: "Riverside", minutes: :arriving}}

      Updater.update_sign(single_source_sign, same_top, diff_bottom)

      refute_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :riverside}, _dur, _start}
      )
    end

    test "does not reannounce arrival if the train stops but the headsign isnt a known terminal" do
      src = %{@src | announce_arriving?: true}
      arr_top = {src, %P{headsign: "Alewife", minutes: :arriving}}
      same_bottom = @sign.current_content_bottom

      sign = Updater.update_sign(@sign, arr_top, same_bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _, _}
      )

      stopped_top = {src, %Content.Message.StoppedTrain{headsign: "davis", stops_away: 1}}

      sign = Updater.update_sign(sign, stopped_top, same_bottom)

      refute_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _, _}
      )

      sign = Updater.update_sign(sign, arr_top, same_bottom)

      refute_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _, _}
      )
    end

    test "announces arrival even if it already had been announced if the train had been stopped" do
      src = %{@src | announce_arriving?: true}
      arr_top = {src, %P{headsign: "Alewife", minutes: :arriving}}
      same_bottom = @sign.current_content_bottom

      sign = Updater.update_sign(@sign, arr_top, same_bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _, _}
      )

      stopped_top = {src, %Content.Message.StoppedTrain{headsign: "Alewife", stops_away: 1}}

      sign = Updater.update_sign(sign, stopped_top, same_bottom)

      refute_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _, _}
      )

      sign = Updater.update_sign(sign, arr_top, same_bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _, _}
      )
    end

    test "announces arrival on bottom if multi-source sign and both lines have changed" do
      multi_source_sign = %{@sign | source_config: {[], []}, tick_read: 40}
      src = %{@src | announce_arriving?: true}
      diff_top = {src, %P{headsign: "Alewife", minutes: :arriving}}
      diff_bottom = {src, %P{headsign: "Riverside", minutes: :arriving}}

      Updater.update_sign(multi_source_sign, diff_top, diff_bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :riverside}, _dur, _start}
      )

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _dur, _start}
      )
    end

    test "announces arrival if multi-source sign and only the bottom line has changed" do
      multi_source_sign = %{@sign | source_config: {[], []}, tick_read: 40}
      src = %{@src | announce_arriving?: true}
      same_top = @sign.current_content_top
      diff_bottom = {src, %P{headsign: "Riverside", minutes: :arriving}}

      Updater.update_sign(multi_source_sign, same_top, diff_bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :riverside}, _dur, _start}
      )
    end

    test "doesn't announce repeated ARR's for same destination until a BRD comes and goes" do
      src = %{@src | announce_arriving?: true}
      top = {src, %P{headsign: "Alewife", minutes: :arriving}}
      bottom = @sign.current_content_bottom

      sign = Updater.update_sign(@sign, top, bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _dur, _start}
      )

      top = {src, %P{headsign: "Alewife", minutes: 2}}
      sign = Updater.update_sign(sign, top, bottom)
      top = {src, %P{headsign: "Alewife", minutes: :arriving}}
      sign = Updater.update_sign(sign, top, bottom)

      refute_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _dur, _start}
      )

      top = {src, %P{headsign: "Braintree", minutes: :arriving}}
      sign = Updater.update_sign(sign, top, bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :braintree}, _dur, _start}
      )

      top = {src, %P{headsign: "Alewife", minutes: :boarding}}
      sign = Updater.update_sign(sign, top, bottom)
      top = {src, %P{headsign: "GracefullyHandlesUnknown", minutes: :boarding}}
      sign = Updater.update_sign(sign, top, bottom)
      top = {src, %P{headsign: "Alewife", minutes: :arriving}}
      Updater.update_sign(sign, top, bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _dur, _start}
      )
    end

    test "announces ARR when sign goes straight to BRD" do
      src = %{@src | announce_arriving?: true}
      top = {src, %P{headsign: "Alewife", minutes: :boarding}}
      bottom = @sign.current_content_bottom
      sign = @sign

      Updater.update_sign(sign, top, bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _dur, _start}
      )
    end

    test "announces ARR when sign changes from one BRD headsign to another" do
      src = %{@src | announce_arriving?: true}
      top = {src, %P{headsign: "Alewife", minutes: :arriving}}
      bottom = @sign.current_content_bottom
      sign = @sign

      sign = Updater.update_sign(sign, top, bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _dur, _start}
      )

      top = {src, %P{headsign: "Alewife", minutes: :boarding}}
      sign = Updater.update_sign(sign, top, bottom)

      refute_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :alewife}, _dur, _start}
      )

      top = {src, %P{headsign: "Ashmont", minutes: :boarding}}
      Updater.update_sign(sign, top, bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.TrainIsArriving{destination: :ashmont}, _dur, _start}
      )
    end

    test "announces stopped-train message if top line changes to it and tick_read is greater than 30 seconds" do
      diff_top = {@src, %Content.Message.StoppedTrain{headsign: "Alewife", stops_away: 2}}
      same_bottom = @sign.current_content_bottom

      initial_tick_read = 40
      read_period_seconds = 100

      sign = %{@sign | tick_read: initial_tick_read, read_period_seconds: read_period_seconds}

      Updater.update_sign(sign, diff_top, same_bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.StoppedTrain{destination: :alewife, stops_away: 2}, _dur,
         _start}
      )
    end

    test "does not announce stopped train message if top line changes to it and tick_read is less than 30 seconds" do
      diff_top = {@src, %Content.Message.StoppedTrain{headsign: "Alewife", stops_away: 2}}
      same_bottom = @sign.current_content_bottom

      initial_tick_read = 10
      read_period_seconds = 100

      sign = %{@sign | tick_read: initial_tick_read, read_period_seconds: read_period_seconds}

      Updater.update_sign(sign, diff_top, same_bottom)

      refute_received(
        {:send_audio, _, %Content.Audio.StoppedTrain{destination: :alewife, stops_away: 2}, _dur,
         _start}
      )
    end

    test "does not announce stopped train message if single-source sign and only the bottom line has changed" do
      single_source_sign = %{@sign | source_config: {[]}, tick_read: 40}
      same_top = @sign.current_content_top
      diff_bottom = {@src, %Content.Message.StoppedTrain{headsign: "Alewife", stops_away: 2}}

      Updater.update_sign(single_source_sign, same_top, diff_bottom)

      refute_received(
        {:send_audio, _, %Content.Audio.StoppedTrain{destination: :alewife, stops_away: 2}, _dur,
         _start}
      )
    end

    test "announces stopped train message if bottom line changes to it and it is a multi-source sign" do
      multi_source_sign = %{@sign | source_config: {[], []}, tick_read: 40}
      same_top = @sign.current_content_top
      diff_bottom = {@src, %Content.Message.StoppedTrain{headsign: "Braintree", stops_away: 2}}

      Updater.update_sign(multi_source_sign, same_top, diff_bottom)

      assert_received(
        {:send_audio, _, %Content.Audio.StoppedTrain{destination: :braintree, stops_away: 2},
         _dur, _start}
      )
    end

    test "does not announce track change message if top line changes and the train is on the right track" do
      prediction = %Content.Message.Predictions{
        stop_id: "70199",
        minutes: :boarding,
        route_id: "Green-E",
        headsign: "Heath St"
      }

      diff_top = {@src, prediction}
      same_bottom = @sign.current_content_bottom

      initial_tick_read = 40
      read_period_seconds = 100

      sign = %{@sign | tick_read: initial_tick_read, read_period_seconds: read_period_seconds}

      Updater.update_sign(sign, diff_top, same_bottom)

      refute_received(
        {:send_audio, _,
         %Content.Audio.TrackChange{destination: :heath_st, track: 2, route_id: "Green-E"}, _dur,
         _start}
      )
    end

    test "announces track change message if top line changes and the train is on the wrong track and its e line" do
      prediction = %Content.Message.Predictions{
        stop_id: "70198",
        minutes: :boarding,
        route_id: "Green-E",
        headsign: "Heath St"
      }

      diff_top = {@src, prediction}
      same_bottom = @sign.current_content_bottom

      initial_tick_read = 40
      read_period_seconds = 100

      sign = %{@sign | tick_read: initial_tick_read, read_period_seconds: read_period_seconds}

      Updater.update_sign(sign, diff_top, same_bottom)

      assert_received(
        {:send_audio, _,
         %Content.Audio.TrackChange{destination: :heath_st, track: 2, route_id: "Green-E"}, _dur,
         _start}
      )
    end

    test "announces track change message if top line changes and the train is on the wrong track" do
      prediction = %Content.Message.Predictions{
        stop_id: "70199",
        minutes: :boarding,
        route_id: "Green-D",
        headsign: "Reservoir"
      }

      diff_top = {@src, prediction}
      same_bottom = @sign.current_content_bottom

      initial_tick_read = 40
      read_period_seconds = 100

      sign = %{@sign | tick_read: initial_tick_read, read_period_seconds: read_period_seconds}

      Updater.update_sign(sign, diff_top, same_bottom)

      assert_received(
        {:send_audio, _,
         %Content.Audio.TrackChange{destination: :reservoir, track: 1, route_id: "Green-D"}, _dur,
         _start}
      )
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
