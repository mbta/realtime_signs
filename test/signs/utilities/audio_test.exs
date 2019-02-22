defmodule Signs.Utilities.AudioTest do
  use ExUnit.Case, async: true

  alias Content.Message
  alias Content.Audio

  import Signs.Utilities.Audio
  import ExUnit.CaptureLog

  defmodule FakeMessage do
    defstruct []
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
    current_content_top: {nil, %Content.Message.Empty{}},
    current_content_bottom: {nil, %Content.Message.Empty{}},
    prediction_engine: nil,
    headway_engine: nil,
    sign_updater: nil,
    tick_bottom: 1,
    tick_top: 1,
    tick_read: 1,
    expiration_seconds: 100,
    read_period_seconds: 100
  }

  describe "should_interrupting_read?/2" do
    test "returns false if it's a numeric prediction" do
      message = %Message.Predictions{headsign: "Alewife", minutes: 5}
      refute should_interrupting_read?({nil, message}, :top)
      refute should_interrupting_read?({nil, message}, :bottom)
    end

    test "If it's ARR respects config's announce_arriving?" do
      message = %Message.Predictions{headsign: "Alewife", minutes: :arriving}
      src = %{@src | announce_arriving?: false}
      refute should_interrupting_read?({src, message}, :top)
      refute should_interrupting_read?({src, message}, :bottom)
      src = %{@src | announce_arriving?: true}
      assert should_interrupting_read?({src, message}, :top)
      assert should_interrupting_read?({src, message}, :bottom)
    end

    test "If it's ARR respects config's announce_boarding?" do
      message = %Message.Predictions{headsign: "Alewife", minutes: :boarding}
      src = %{@src | announce_boarding?: false}
      refute should_interrupting_read?({src, message}, :top)
      refute should_interrupting_read?({src, message}, :bottom)
      src = %{@src | announce_boarding?: true}
      assert should_interrupting_read?({src, message}, :top)
      assert should_interrupting_read?({src, message}, :bottom)
    end

    test "returns false if it's empty" do
      refute should_interrupting_read?({nil, %Message.Empty{}}, :top)
      refute should_interrupting_read?({nil, %Message.Empty{}}, :bottom)
    end

    test "returns false if it's the bottom line and a stopped train message" do
      message = %Message.StoppedTrain{headsign: "Alewife", stops_away: 2}
      assert should_interrupting_read?({@src, message}, :top)
      refute should_interrupting_read?({@src, message}, :bottom)
    end

    test "returns true if it's a different kind of message" do
      message = %Message.Headways.Top{headsign: "Alewife", vehicle_type: :train}
      assert should_interrupting_read?({@src, message}, :top)
    end
  end

  describe "from_sign/1" do
    test "Station closure" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Alert.NoService{mode: :train}},
          current_content_bottom: {@src, %Message.Alert.UseShuttleBus{}}
      }

      assert {
               %Audio.Closure{alert: :shuttles_closed_station},
               ^sign
             } = from_sign(sign)
    end

    test "Custom text" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Custom{line: :top, message: "Custom Top"}},
          current_content_bottom: {@src, %Message.Custom{line: :bottom, message: "Custom Bottom"}}
      }

      assert {
               %Audio.Custom{message: "Custom Top Custom Bottom"},
               ^sign
             } = from_sign(sign)
    end

    test "Custom text bottom only" do
      sign = %{
        @sign
        | current_content_top: {nil, %Message.Empty{}},
          current_content_bottom: {@src, %Message.Custom{line: :bottom, message: "Custom Bottom"}}
      }

      assert {
               %Audio.Custom{message: "Custom Bottom"},
               ^sign
             } = from_sign(sign)
    end

    test "Headway messages" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Headways.Top{headsign: "Alewife"}},
          current_content_bottom: {@src, %Message.Headways.Bottom{range: {1, 3}}}
      }

      assert {
               %Audio.VehiclesToDestination{
                 language: :english,
                 destination: :alewife,
                 next_trip_mins: 1,
                 later_trip_mins: 3
               },
               ^sign
             } = from_sign(sign)
    end

    test "Headways in Spanish, too, if available" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Headways.Top{headsign: "Chelsea"}},
          current_content_bottom: {@src, %Message.Headways.Bottom{range: {1, 3}}}
      }

      assert {{
                %Audio.VehiclesToDestination{language: :english},
                %Audio.VehiclesToDestination{language: :spanish}
              }, ^sign} = from_sign(sign)
    end

    test "Countdowns say 'following train' if second line is same headsign" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Predictions{headsign: "Ashmont", minutes: 3}},
          current_content_bottom: {@src, %Message.Predictions{headsign: "Ashmont", minutes: 4}}
      }

      assert {{%Audio.NextTrainCountdown{destination: :ashmont, minutes: 3},
               %Audio.FollowingTrain{destination: :ashmont, minutes: 4}}, ^sign} = from_sign(sign)
    end

    test "Ignores 'following train' if same headsign but it's arriving (we don't have audio)" do
      sign = %{
        @sign
        | current_content_top:
            {@src, %Message.Predictions{headsign: "Ashmont", minutes: :boarding}},
          current_content_bottom:
            {@src, %Message.Predictions{headsign: "Ashmont", minutes: :arriving}}
      }

      assert {%Audio.TrainIsBoarding{destination: :ashmont}, ^sign} = from_sign(sign)
    end

    test "No audio at all if same headsign but we don't know what it is" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Predictions{headsign: "The Moon", minutes: 3}},
          current_content_bottom: {@src, %Message.Predictions{headsign: "The Moon", minutes: 4}}
      }

      log =
        capture_log([level: :error], fn ->
          assert {nil, ^sign} = from_sign(sign)
        end)

      assert log =~ "message_to_audio_error"
    end

    test "Two stopped train messages only plays once if both same headsign" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.StoppedTrain{headsign: "Alewife", stops_away: 2}},
          current_content_bottom:
            {@src, %Message.StoppedTrain{headsign: "Alewife", stops_away: 4}}
      }

      assert {
               %Audio.StoppedTrain{destination: :alewife, stops_away: 2},
               ^sign
             } = from_sign(sign)
    end

    test "Stopped train on top prevents countdown on bottom if same headsign" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.StoppedTrain{headsign: "Alewife", stops_away: 2}},
          current_content_bottom: {@src, %Message.Predictions{headsign: "Alewife", minutes: 8}}
      }

      assert {
               %Audio.StoppedTrain{destination: :alewife, stops_away: 2},
               ^sign
             } = from_sign(sign)
    end

    test "Don't read second line 'stopped train' if same headsign as top line countdown (because no 'following train is stopped' audio available)" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Predictions{headsign: "Alewife", minutes: 4}},
          current_content_bottom:
            {@src, %Message.StoppedTrain{headsign: "Alewife", stops_away: 2}}
      }

      assert {
               %Audio.NextTrainCountdown{destination: :alewife, minutes: 4},
               ^sign
             } = from_sign(sign)
    end

    test "Countdowns when headsigns are different" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Predictions{headsign: "Ashmont", minutes: 3}},
          current_content_bottom: {@src, %Message.Predictions{headsign: "Braintree", minutes: 4}}
      }

      assert {{
                %Audio.NextTrainCountdown{destination: :ashmont, minutes: 3},
                %Audio.NextTrainCountdown{destination: :braintree, minutes: 4}
              }, ^sign} = from_sign(sign)
    end

    test "One countdown and one stopped train, with different headsigns, both are read" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Predictions{headsign: "Ashmont", minutes: 3}},
          current_content_bottom:
            {@src, %Message.StoppedTrain{headsign: "Braintree", stops_away: 4}}
      }

      assert {{
                %Audio.NextTrainCountdown{destination: :ashmont, minutes: 3},
                %Audio.StoppedTrain{destination: :braintree, stops_away: 4}
              }, ^sign} = from_sign(sign)
    end

    test "When bottom line is empty, reads top" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.Predictions{headsign: "Ashmont", minutes: 3}},
          current_content_bottom: {nil, %Message.Empty{}}
      }

      assert {%Audio.NextTrainCountdown{destination: :ashmont, minutes: 3}, ^sign} =
               from_sign(sign)
    end

    test "When top line is empty, reads bottom" do
      sign = %{
        @sign
        | current_content_top: {nil, %Message.Empty{}},
          current_content_bottom: {@src, %Message.Predictions{headsign: "Ashmont", minutes: 3}}
      }

      assert {%Audio.NextTrainCountdown{destination: :ashmont, minutes: 3}, ^sign} =
               from_sign(sign)
    end

    test "When both lines are empty returns nil" do
      sign = %{
        @sign
        | current_content_top: {nil, %Message.Empty{}},
          current_content_bottom: {nil, %Message.Empty{}}
      }

      assert {nil, ^sign} = from_sign(sign)
    end

    test "When one train is boarding and another is a countdown, audio is ordered correctly" do
      sign = %{
        @sign
        | current_content_top:
            {@src, %Message.Predictions{headsign: "Boston Col", minutes: :boarding}},
          current_content_bottom: {@src, %Message.Predictions{headsign: "Riverside", minutes: 4}}
      }

      assert {{
                %Audio.TrainIsBoarding{destination: :boston_college},
                %Audio.NextTrainCountdown{destination: :riverside}
              }, _sign} = from_sign(sign)
    end

    test "Reads ARR on sign even if announce_arriving? is false" do
      src = %{@src | announce_arriving?: false}

      sign = %{
        @sign
        | current_content_top:
            {src, %Message.Predictions{headsign: "Alewife", minutes: :arriving}}
      }

      assert {%Audio.TrainIsArriving{destination: :alewife}, _sign} = from_sign(sign)
    end

    test "Reads BRD on sign even if announce_boarding? is false" do
      src = %{@src | announce_boarding?: false}

      sign = %{
        @sign
        | current_content_top:
            {src, %Message.Predictions{headsign: "Alewife", minutes: :boarding}}
      }

      assert {%Audio.TrainIsBoarding{destination: :alewife}, _sign} = from_sign(sign)
    end

    test "Logs error and returns nil if unknown message type" do
      sign = %{
        @sign
        | current_content_top: {@src, %Message.StoppedTrain{headsign: "Alewife", stops_away: 2}},
          current_content_bottom: {nil, %FakeMessage{}}
      }

      log =
        capture_log([level: :error], fn ->
          assert {
                   %Audio.StoppedTrain{destination: :alewife, stops_away: 2},
                   ^sign
                 } = from_sign(sign)
        end)

      assert log =~ "message_to_audio_error"
    end
  end
end
