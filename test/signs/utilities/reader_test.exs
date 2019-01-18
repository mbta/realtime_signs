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

      sign = Reader.read_sign(sign)

      assert_received(
        {:send_audio, _id, %A{destination: :alewife, minutes: 4, verb: :arrives}, _p, _t}
      )

      assert_received(
        {:send_audio, _id, %A{destination: :ashmont, minutes: 3, verb: :arrives}, _p, _t}
      )

      assert sign.tick_read == 100
    end

    test "sends audio only for top, if bottom has same headsign" do
      sign = %{
        @sign
        | tick_read: 0,
          current_content_bottom: {@src, %P{headsign: "Alewife", minutes: 3}}
      }

      sign = Reader.read_sign(sign)

      assert_received(
        {:send_audio, _id, %A{destination: :alewife, minutes: 4, verb: :arrives}, _p, _t}
      )

      refute_received(
        {:send_audio, _id, %A{destination: :alewife, minutes: 3, verb: :arrives}, _p, _t}
      )

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

      sign = %{
        @sign
        | tick_read: 0,
          current_content_top: {src, %P{headsign: "Alewife", minutes: 4}}
      }

      sign = Reader.read_sign(sign)

      assert_received({:send_audio, _id, %A{destination: :alewife, verb: :departs}, _p, _t})
      assert_received({:send_audio, _id, %A{destination: :ashmont, verb: :arrives}, _p, _t})
      assert sign.tick_read == 100
    end

    test "sends headway message if the headways are displayed" do
      sign = %{
        @sign
        | tick_read: 0,
          current_content_top: {@src, %T{headsign: "Alewife"}},
          current_content_bottom: {@src, %B{range: {1, 3}}}
      }

      sign = Reader.read_sign(sign)

      assert_received(
        {:send_audio, _id,
         %VTD{language: :english, destination: :alewife, next_trip_mins: 1, later_trip_mins: 3},
         _p, _t}
      )

      assert sign.tick_read == 100
    end

    test "sends both English and Spanish audio if both are available" do
      sign = %{
        @sign
        | tick_read: 0,
          current_content_top: {@src, %T{headsign: "Chelsea"}},
          current_content_bottom: {@src, %B{range: {1, 3}}}
      }

      sign = Reader.read_sign(sign)

      assert_received(
        {:send_audio, _id,
         %VTD{language: :english, destination: :chelsea, next_trip_mins: 1, later_trip_mins: 3},
         _p, _t}
      )

      assert_received(
        {:send_audio, _id,
         %VTD{language: :spanish, destination: :chelsea, next_trip_mins: 1, later_trip_mins: 3},
         _p, _t}
      )

      assert sign.tick_read == 100
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
        {:send_audio, _id, %Content.Audio.StoppedTrain{destination: :alewife, stops_away: 2}, _p,
         _t}
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

      sign = Reader.read_sign(sign)

      assert_received(
        {:send_custom_audio, _id, %Content.Audio.Custom{message: "Custom Top Custom Bottom"}, _p,
         _t}
      )

      assert sign.tick_read == 100
    end
  end
end
