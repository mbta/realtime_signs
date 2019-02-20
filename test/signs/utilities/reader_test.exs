defmodule Signs.Utilities.ReaderTest do
  use ExUnit.Case, async: true

  alias Content.Message.Predictions, as: P
  alias Content.Message.Headways.Top, as: T
  alias Content.Message.Headways.Bottom, as: B
  alias Content.Audio.NextTrainCountdown, as: A
  alias Content.Audio.VehiclesToDestination, as: VTD
  alias Signs.Utilities.Reader

  defmodule FakePredictions do
    def for_stop(_stop_id, _direction_id), do: []
    def stopped_at?(_stop_id), do: false
  end

  defmodule FakeUpdater do
    def send_audio(id, audio, priority, timeout) do
      send(self(), {:send_audio, id, audio, priority, timeout})
    end

    def send_custom_audio(id, audio, priority, timeout) do
      send(self(), {:send_custom_audio, id, audio, priority, timeout})
    end
  end

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    direction_id: 0,
    headway_direction_name: "Southbound",
    platform: nil,
    terminal?: false,
    announce_arriving?: false,
    announce_boarding?: false
  }

  @sign %Signs.Realtime{
    id: "sign_id",
    pa_ess_id: {"TEST", "x"},
    source_config: {[@src]},
    current_content_top: {@src, %P{headsign: "Alewife", minutes: 4}},
    current_content_bottom: {@src, %P{headsign: "Ashmont", minutes: 3}},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    sign_updater: FakeUpdater,
    tick_bottom: 1,
    tick_top: 1,
    tick_read: 1,
    expiration_seconds: 100,
    read_period_seconds: 100
  }

  describe "read_sign/1" do
    test "sends audio for top and bottom when headsigns are different" do
      sign = %{@sign | tick_read: 0}

      Reader.read_sign(sign)

      assert_received(
        {:send_audio, _id,
         {%A{destination: :alewife, minutes: 4, verb: :arrives},
          %A{destination: :ashmont, minutes: 3, verb: :arrives}}, _p, _t}
      )
    end

    test "when the sign is not on a read interval, does not send next train announcements" do
      sign = %{@sign | tick_read: 100}

      Reader.read_sign(sign)

      refute_received({:send_audio, _id, _, _p, _t})
      refute_received({:send_audio, _id, _, _p, _t})
    end

    test "doesnt send a second message when the two lines have the same headsign" do
      sign = %{
        @sign
        | tick_read: 0,
          current_content_bottom: {@src, %P{headsign: "Alewife", minutes: 3}}
      }

      Reader.read_sign(sign)

      assert_received(
        {:send_audio, _id, %A{destination: :alewife, minutes: 4, verb: :arrives}, _p, _t}
      )

      refute_received({:send_audio, _id, _m, _p, _t})
    end

    test "uses 'departs' if it's for a terminal" do
      src = %{@src | terminal?: true}

      sign = %{
        @sign
        | tick_read: 0,
          current_content_top: {src, %P{headsign: "Alewife", minutes: 4}}
      }

      Reader.read_sign(sign)

      assert_received(
        {:send_audio, _id,
         {%A{destination: :alewife, verb: :departs}, %A{destination: :ashmont, verb: :arrives}},
         _p, _t}
      )
    end

    test "sends headway message if the headways are displayed" do
      sign = %{
        @sign
        | tick_read: 0,
          current_content_top: {@src, %T{headsign: "Alewife"}},
          current_content_bottom: {@src, %B{range: {1, 3}}}
      }

      Reader.read_sign(sign)

      assert_received(
        {:send_audio, _id,
         %VTD{language: :english, destination: :alewife, next_trip_mins: 1, later_trip_mins: 3},
         _p, _t}
      )
    end

    test "sends both English and Spanish audio if both are available" do
      sign = %{
        @sign
        | tick_read: 0,
          current_content_top: {@src, %T{headsign: "Chelsea"}},
          current_content_bottom: {@src, %B{range: {1, 3}}}
      }

      Reader.read_sign(sign)

      assert_received(
        {:send_audio, _id,
         {%VTD{language: :english, destination: :chelsea, next_trip_mins: 1, later_trip_mins: 3},
          %VTD{language: :spanish, destination: :chelsea, next_trip_mins: 1, later_trip_mins: 3}},
         _p, _t}
      )
    end

    test "sends next train message when the headsigns are not the same" do
      sign = %{
        @sign
        | tick_read: 0
      }

      Reader.read_sign(sign)

      assert_received(
        {:send_audio, _id,
         {%Content.Audio.NextTrainCountdown{destination: :alewife, minutes: 4},
          %Content.Audio.NextTrainCountdown{destination: :ashmont, minutes: 3}}, _p, _t}
      )
    end

    test "sends stopped train message" do
      sign = %{
        @sign
        | tick_read: 0,
          current_content_top:
            {@src, %Content.Message.StoppedTrain{headsign: "Alewife", stops_away: 2}}
      }

      Reader.read_sign(sign)

      assert_received(
        {:send_audio, _id, {_, %Content.Audio.StoppedTrain{destination: :alewife, stops_away: 2}},
         _p, _t}
      )
    end

    test "sends custom audio when we have custom text" do
      sign = %{
        @sign
        | tick_read: 0,
          current_content_top: {@src, %Content.Message.Custom{line: :top, message: "Custom Top"}},
          current_content_bottom:
            {@src, %Content.Message.Custom{line: :bottom, message: "Custom Bottom"}}
      }

      Reader.read_sign(sign)

      assert_received(
        {:send_custom_audio, _id, %Content.Audio.Custom{message: "Custom Top Custom Bottom"}, _p,
         _t}
      )
    end

    test "sends station closure audio when there is a shuttle bus closure" do
      sign = %{
        @sign
        | tick_read: 0,
          current_content_top: {@src, %Content.Message.Alert.NoService{mode: :train}},
          current_content_bottom: {@src, %Content.Message.Alert.UseShuttleBus{}}
      }

      Reader.read_sign(sign)

      assert_received(
        {:send_audio, _id, %Content.Audio.Closure{alert: :shuttles_closed_station}, _p, _t}
      )
    end

    test "when the sign is ready to be read, but there is no minutes for the headsign, does not read" do
      sign = %{
        @sign
        | tick_read: 0,
          current_content_top:
            {@src, %Content.Message.Predictions{headsign: "Alewife", minutes: nil}},
          current_content_bottom:
            {@src, %Content.Message.Predictions{headsign: "Alewife", minutes: nil}}
      }

      Reader.read_sign(sign)

      refute_received({:send_audio, _id, _, _p, _t})
    end
  end

  describe "interrupting_read/1" do
    test "does not send audio when tick read is 0, because it will be read by the read loop" do
      sign = %{@sign | tick_read: 0}

      Reader.interrupting_read(sign)

      refute_received(
        {:send_audio, _id, %A{destination: :alewife, minutes: 4, verb: :arrives}, _p, _t}
      )

      refute_received(
        {:send_audio, _id, %A{destination: :ashmont, minutes: 3, verb: :arrives}, _p, _t}
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
