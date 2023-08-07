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
    current_content_top: %Content.Message.Empty{},
    current_content_bottom: %Content.Message.Empty{},
    prediction_engine: nil,
    headway_engine: nil,
    last_departure_engine: nil,
    config_engine: Engine.Config,
    alerts_engine: nil,
    current_time_fn: nil,
    sign_updater: nil,
    last_update: Timex.now(),
    tick_audit: 1,
    tick_read: 1,
    read_period_seconds: 100
  }

  describe "should_interrupting_read?/3" do
    test "returns false if it's a numeric prediction" do
      message = %Message.Predictions{destination: :alewife, minutes: 5}
      refute should_interrupting_read?(message, {[@src]}, :top)
      refute should_interrupting_read?(message, {[@src]}, :bottom)
    end

    test "If it's ARR respects config's announce_arriving?, except on the bottom line of a single-source sign" do
      message = %Message.Predictions{
        destination: :alewife,
        minutes: :arriving,
        stop_id: "1",
        direction_id: 0
      }

      src = %{@src | announce_arriving?: false}

      refute should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}},
               :top
             )

      refute should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}},
               :bottom
             )

      src = %{@src | announce_arriving?: true}

      assert should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}},
               :top
             )

      assert should_interrupting_read?(
               message,
               %{@sign | source_config: {%{sources: [src]}, %{sources: [src]}}},
               :bottom
             )

      refute should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}},
               :bottom
             )
    end

    test "If it's Approaching, respects config's announce_arriving? for heavy rail, except on the bottom line of a single-source sign" do
      message = %Message.Predictions{
        destination: :alewife,
        minutes: :approaching,
        route_id: "Red",
        direction_id: 0,
        stop_id: "1"
      }

      src = %{@src | announce_arriving?: false}

      refute should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}},
               :top
             )

      refute should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}},
               :bottom
             )

      src = %{@src | announce_arriving?: true}

      assert should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}},
               :top
             )

      assert should_interrupting_read?(
               message,
               %{@sign | source_config: {%{sources: [src]}, %{sources: [src]}}},
               :bottom
             )

      refute should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}},
               :bottom
             )
    end

    test "If it's Approaching, does not interrupt for light rail" do
      message = %Message.Predictions{
        destination: :riverside,
        minutes: :approaching,
        route_id: "Green-D"
      }

      src = %{@src | announce_arriving?: true}

      refute should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}},
               :top
             )
    end

    test "If it's Approaching, does not interrupt when announce_boarding?: true" do
      message = %Message.Predictions{destination: :alewife, minutes: :approaching}
      src = %{@src | announce_arriving?: false, announce_boarding?: true}

      refute should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}},
               :top
             )
    end

    test "If it's BRD respects config's announce_boarding? when arrival was already announced" do
      message = %Message.Predictions{
        destination: :alewife,
        minutes: :boarding,
        trip_id: "trip1",
        stop_id: "1",
        direction_id: 0
      }

      src = %{@src | announce_boarding?: false}

      refute should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}, announced_arrivals: ["trip1"]},
               :top
             )

      refute should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}, announced_arrivals: ["trip1"]},
               :bottom
             )

      src = %{@src | announce_boarding?: true}

      assert should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}, announced_arrivals: ["trip1"]},
               :top
             )

      assert should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [src]}, announced_arrivals: ["trip1"]},
               :bottom
             )
    end

    test "If it's BRD and announce_boarding? is false, but arrival for trip was not announced, still read" do
      message = %Message.Predictions{destination: :alewife, minutes: :boarding, trip_id: "trip1"}
      src = %{@src | announce_boarding?: false}

      log =
        capture_log([level: :info], fn ->
          assert should_interrupting_read?(
                   message,
                   %{@sign | source_config: %{sources: [src]}, announced_arrivals: []},
                   :top
                 )
        end)

      assert log =~ "announced_brd_when_arr_skipped trip_id=\"trip1\" sign_id=\"sign_id\""
    end

    test "returns false if it's empty" do
      refute should_interrupting_read?(
               %Message.Empty{},
               %{@sign | source_config: %{sources: [@src]}},
               :top
             )

      refute should_interrupting_read?(
               %Message.Empty{},
               %{@sign | source_config: %{sources: [@src]}},
               :bottom
             )
    end

    test "returns false if it's the bottom line and a stopped train message" do
      message = %Message.StoppedTrain{destination: :alewife, stops_away: 2}

      assert should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [@src]}},
               :top
             )

      refute should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [@src]}},
               :bottom
             )
    end

    test "returns false for bottom headway message" do
      message = %Message.Headways.Bottom{range: {1, 5}, prev_departure_mins: nil}

      refute should_interrupting_read?(
               message,
               %{@sign | source_config: %{sources: [@src]}},
               :top
             )
    end

    test "returns true if it's a different kind of message" do
      message = %Message.Headways.Top{destination: :alewife, vehicle_type: :train}

      assert should_interrupting_read?(
               {@src, message},
               %{@sign | source_config: %{sources: [@src]}},
               :top
             )
    end
  end

  describe "from_sign/1" do
    test "Station closure" do
      sign = %{
        @sign
        | current_content_top: %Message.Alert.NoService{},
          current_content_bottom: %Message.Alert.UseShuttleBus{}
      }

      assert {
               [%Audio.Closure{alert: :shuttles_closed_station}],
               ^sign
             } = from_sign(sign)
    end

    test "Custom text" do
      sign = %{
        @sign
        | current_content_top: %Message.Custom{line: :top, message: "Custom Top"},
          current_content_bottom: %Message.Custom{line: :bottom, message: "Custom Bottom"}
      }

      assert {
               [%Audio.Custom{message: "Custom Top Custom Bottom"}],
               ^sign
             } = from_sign(sign)
    end

    test "Custom text bottom only" do
      sign = %{
        @sign
        | current_content_top: %Message.Empty{},
          current_content_bottom: %Message.Custom{line: :bottom, message: "Custom Bottom"}
      }

      assert {
               [%Audio.Custom{message: "Custom Bottom"}],
               ^sign
             } = from_sign(sign)
    end

    test "Headway messages" do
      sign = %{
        @sign
        | current_content_top: %Message.Headways.Top{destination: :alewife},
          current_content_bottom: %Message.Headways.Bottom{range: {1, 3}}
      }

      assert {
               [
                 %Audio.VehiclesToDestination{
                   language: :english,
                   destination: :alewife,
                   headway_range: {1, 3}
                 }
               ],
               ^sign
             } = from_sign(sign)
    end

    test "Headways in Spanish, too, if available" do
      sign = %{
        @sign
        | current_content_top: %Message.Headways.Top{destination: :chelsea},
          current_content_bottom: %Message.Headways.Bottom{range: {1, 3}}
      }

      assert {[
                %Audio.VehiclesToDestination{language: :english},
                %Audio.VehiclesToDestination{language: :spanish}
              ], ^sign} = from_sign(sign)
    end

    test "Countdowns say 'following train' if second line is same headsign" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{destination: :ashmont, minutes: 3},
          current_content_bottom: %Message.Predictions{destination: :ashmont, minutes: 4}
      }

      assert {[
                %Audio.NextTrainCountdown{destination: :ashmont, minutes: 3},
                %Audio.FollowingTrain{destination: :ashmont, minutes: 4}
              ], ^sign} = from_sign(sign)
    end

    test "If top line prediction and bottom line paging headways, announce both" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{destination: :medford_tufts, minutes: 3},
          current_content_bottom: %Message.Headways.Paging{
            destination: :heath_street,
            range: {5, 7}
          }
      }

      assert {[
                %Audio.NextTrainCountdown{destination: :medford_tufts, minutes: 3},
                %Audio.VehiclesToDestination{destination: :heath_street, headway_range: {5, 7}}
              ], ^sign} = from_sign(sign)
    end

    test "Ignores 'following train' if same headsign but it's arriving (we don't have audio)" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{destination: :ashmont, minutes: :boarding},
          current_content_bottom: %Message.Predictions{destination: :ashmont, minutes: :arriving}
      }

      assert {[%Audio.TrainIsBoarding{destination: :ashmont}], ^sign} = from_sign(sign)
    end

    test "reads the approaching and bottom line when top line is approaching" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{
            destination: :alewife,
            minutes: :approaching,
            route_id: "Red"
          },
          current_content_bottom: %Message.Predictions{
            destination: :alewife,
            minutes: 5,
            route_id: "Red"
          }
      }

      assert {
               [
                 %Audio.Approaching{destination: :alewife},
                 %Audio.FollowingTrain{destination: :alewife, minutes: 5, verb: :arrives}
               ],
               ^sign
             } = from_sign(sign)
    end

    test "does not read approaching if it's the bottom line and a following train" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{destination: :alewife, minutes: :arriving},
          current_content_bottom: %Message.Predictions{
            destination: :alewife,
            minutes: :approaching
          }
      }

      assert {
               [%Audio.TrainIsArriving{destination: :alewife}],
               ^sign
             } = from_sign(sign)
    end

    test "reads approaching as 1 minute when on the bottom line and a different headsign" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{destination: :ashmont, minutes: :boarding},
          current_content_bottom: %Message.Predictions{
            destination: :braintree,
            minutes: :approaching
          }
      }

      assert {
               [
                 %Audio.TrainIsBoarding{destination: :ashmont},
                 %Audio.NextTrainCountdown{
                   destination: :braintree,
                   verb: :arrives,
                   minutes: 1,
                   track_number: nil,
                   platform: nil
                 }
               ],
               ^sign
             } = from_sign(sign)
    end

    test "only reads the top line when the top line is arriving and heavy rail" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{
            destination: :alewife,
            minutes: :arriving,
            route_id: "Red"
          },
          current_content_bottom: %Message.Predictions{
            destination: :alewife,
            minutes: 5,
            route_id: "Red"
          }
      }

      assert {[%Audio.TrainIsArriving{destination: :alewife}], ^sign} = from_sign(sign)
    end

    test "reads both lines when the top line is arriving and light rail" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{
            destination: :ashmont,
            minutes: :arriving,
            route_id: "Mattapan"
          },
          current_content_bottom: %Message.Predictions{
            destination: :ashmont,
            minutes: 5,
            route_id: "Mattapan"
          }
      }

      assert {[
                %Audio.TrainIsArriving{destination: :ashmont, route_id: "Mattapan"},
                %Audio.FollowingTrain{destination: :ashmont, minutes: 5}
              ], ^sign} = from_sign(sign)
    end

    test "only reads the bottom line when the bottom line is arriving on a multi_source sign for heavy rail" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{
            destination: :alewife,
            minutes: 3,
            route_id: "Red"
          },
          current_content_bottom: %Message.Predictions{
            destination: :braintree,
            minutes: :arriving,
            route_id: "Red"
          },
          source_config: {%{sources: [@src]}, %{sources: [@src]}}
      }

      assert {[%Audio.TrainIsArriving{destination: :braintree}], ^sign} = from_sign(sign)
    end

    test "reads both lines in order when the bottom line is arriving on a multi_source sign for light rail" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{
            destination: :lechmere,
            minutes: 3,
            route_id: "Green-E"
          },
          current_content_bottom: %Message.Predictions{
            destination: :riverside,
            minutes: :arriving,
            route_id: "Green-D"
          },
          source_config: {%{sources: [@src]}, %{sources: [@src]}}
      }

      assert {[
                %Audio.TrainIsArriving{destination: :riverside},
                %Audio.NextTrainCountdown{destination: :lechmere, minutes: 3}
              ], ^sign} = from_sign(sign)
    end

    test "Two stopped train messages only plays once if both same headsign" do
      sign = %{
        @sign
        | current_content_top: %Message.StoppedTrain{destination: :alewife, stops_away: 2},
          current_content_bottom: %Message.StoppedTrain{destination: :alewife, stops_away: 4}
      }

      assert {
               [%Audio.StoppedTrain{destination: :alewife, stops_away: 2}],
               ^sign
             } = from_sign(sign)
    end

    test "Stopped train on top prevents countdown on bottom if same headsign" do
      sign = %{
        @sign
        | current_content_top: %Message.StoppedTrain{destination: :alewife, stops_away: 2},
          current_content_bottom: %Message.Predictions{destination: :alewife, minutes: 8}
      }

      assert {
               [%Audio.StoppedTrain{destination: :alewife, stops_away: 2}],
               ^sign
             } = from_sign(sign)
    end

    test "Don't read second line 'stopped train' if same headsign as top line countdown (because no 'following train is stopped' audio available)" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{destination: :alewife, minutes: 4},
          current_content_bottom: %Message.StoppedTrain{destination: :alewife, stops_away: 2}
      }

      assert {
               [%Audio.NextTrainCountdown{destination: :alewife, minutes: 4}],
               ^sign
             } = from_sign(sign)
    end

    test "Countdowns when headsigns are different" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{destination: :ashmont, minutes: 3},
          current_content_bottom: %Message.Predictions{destination: :braintree, minutes: 4}
      }

      assert {[
                %Audio.NextTrainCountdown{destination: :ashmont, minutes: 3},
                %Audio.NextTrainCountdown{destination: :braintree, minutes: 4}
              ], ^sign} = from_sign(sign)
    end

    test "One countdown and one stopped train, with different headsigns, both are read" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{destination: :ashmont, minutes: 3},
          current_content_bottom: %Message.StoppedTrain{destination: :braintree, stops_away: 4}
      }

      assert {[
                %Audio.NextTrainCountdown{destination: :ashmont, minutes: 3},
                %Audio.StoppedTrain{destination: :braintree, stops_away: 4}
              ], ^sign} = from_sign(sign)
    end

    test "When bottom line is empty, reads top" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{destination: :ashmont, minutes: 3},
          current_content_bottom: %Message.Empty{}
      }

      assert {[%Audio.NextTrainCountdown{destination: :ashmont, minutes: 3}], ^sign} =
               from_sign(sign)
    end

    test "When top line is empty, reads bottom" do
      sign = %{
        @sign
        | current_content_top: %Message.Empty{},
          current_content_bottom: %Message.Predictions{destination: :ashmont, minutes: 3}
      }

      assert {[%Audio.NextTrainCountdown{destination: :ashmont, minutes: 3}], ^sign} =
               from_sign(sign)
    end

    test "When both lines are empty returns nil" do
      sign = %{
        @sign
        | current_content_top: %Message.Empty{},
          current_content_bottom: %Message.Empty{}
      }

      assert {[], ^sign} = from_sign(sign)
    end

    test "When one train is boarding and another is a countdown, audio is ordered correctly" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{
            destination: :boston_college,
            minutes: :boarding
          },
          current_content_bottom: %Message.Predictions{destination: :riverside, minutes: 4}
      }

      assert {[
                %Audio.TrainIsBoarding{destination: :boston_college},
                %Audio.NextTrainCountdown{destination: :riverside}
              ], _sign} = from_sign(sign)
    end

    test "Reads ARR on sign even if announce_arriving? is false" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{destination: :alewife, minutes: :arriving}
      }

      assert {[%Audio.TrainIsArriving{destination: :alewife}], _sign} = from_sign(sign)
    end

    test "Reads BRD on sign even if announce_boarding? is false" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{destination: :alewife, minutes: :boarding}
      }

      assert {[%Audio.TrainIsBoarding{destination: :alewife}], _sign} = from_sign(sign)
    end

    test "Logs error and returns nil if unknown message type" do
      sign = %{
        @sign
        | current_content_top: %Message.StoppedTrain{destination: :alewife, stops_away: 2},
          current_content_bottom: %FakeMessage{}
      }

      log =
        capture_log([level: :error], fn ->
          assert {
                   [%Audio.StoppedTrain{destination: :alewife, stops_away: 2}],
                   ^sign
                 } = from_sign(sign)
        end)

      assert log =~ "message_to_audio_error"
    end

    test "announces arriving, then skips arriving for the same trip" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{
            minutes: :arriving,
            trip_id: "trip1",
            destination: :alewife
          },
          current_content_bottom: %Message.Empty{}
      }

      {audio, new_sign} = from_sign(sign)

      assert [%Content.Audio.TrainIsArriving{}] = audio
      assert new_sign.announced_arrivals == ["trip1"]

      assert {[], ^new_sign} = from_sign(new_sign)
    end

    test "announces approaching, then skips approaching for the same trip" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{
            minutes: :approaching,
            trip_id: "trip1",
            destination: :alewife,
            route_id: "Red"
          },
          current_content_bottom: %Message.Empty{}
      }

      {audio, new_sign} = from_sign(sign)

      assert [%Content.Audio.Approaching{}] = audio
      assert new_sign.announced_approachings == ["trip1"]

      assert {[], ^new_sign} = from_sign(new_sign)
    end

    test "Announces higher priority message first even on bottom of multi-source sign" do
      sign = %{
        @sign
        | current_content_top: %Message.Predictions{
            minutes: 5,
            destination: :alewife,
            route_id: "Red"
          },
          current_content_bottom: %Message.Predictions{
            minutes: :approaching,
            destination: :ashmont,
            route_id: "Red"
          },
          source_config: {%{sources: [@src]}, %{sources: [@src]}}
      }

      assert {
               [
                 %Content.Audio.Approaching{destination: :ashmont},
                 %Content.Audio.NextTrainCountdown{minutes: 5, destination: :alewife}
               ],
               ^sign
             } = from_sign(sign)
    end

    test "Gets audios from full page paging" do
      sign = %{
        @sign
        | current_content_top: %Message.GenericPaging{
            messages: [
              %Message.Headways.Top{destination: :ashmont, vehicle_type: :train},
              %Message.Predictions{
                destination: :alewife,
                minutes: 5,
                route_id: "Red",
                platform: :ashmont,
                station_code: "RJFK"
              }
            ]
          },
          current_content_bottom: %Message.GenericPaging{
            messages: [
              %Message.Headways.Bottom{range: {1, 3}},
              %Message.PlatformPredictionBottom{stop_id: "70086", minutes: 5}
            ]
          }
      }

      assert {
               [
                 %Audio.VehiclesToDestination{
                   language: :english,
                   destination: :ashmont,
                   headway_range: {1, 3}
                 },
                 %Content.Audio.NextTrainCountdown{
                   destination: :alewife,
                   minutes: 5,
                   platform: :ashmont
                 }
               ],
               ^sign
             } = from_sign(sign)
    end

    test "Drops audios from full page paging" do
      sign = %{
        @sign
        | current_content_top: %Message.GenericPaging{
            messages: [
              %Message.Headways.Top{destination: :ashmont, vehicle_type: :train},
              %Message.Predictions{
                destination: :alewife,
                minutes: 5,
                route_id: "Red",
                platform: :ashmont,
                station_code: "RJFK"
              },
              %Message.Predictions{
                destination: :braintree,
                minutes: 5,
                route_id: "Red",
                platform: :ashmont
              }
            ]
          },
          current_content_bottom: %Message.GenericPaging{
            messages: [
              %Message.Headways.Bottom{range: {1, 3}},
              %Message.PlatformPredictionBottom{stop_id: "70086", minutes: 5}
            ]
          }
      }

      log =
        capture_log([level: :warn], fn ->
          assert {
                   [
                     %Audio.VehiclesToDestination{
                       language: :english,
                       destination: :ashmont,
                       headway_range: {1, 3}
                     },
                     %Content.Audio.NextTrainCountdown{
                       destination: :alewife,
                       minutes: 5,
                       platform: :ashmont
                     }
                   ],
                   ^sign
                 } = from_sign(sign)
        end)

      assert log =~ "message_to_audio_warning Utilities.Audio generic_paging_mismatch"
    end
  end
end
