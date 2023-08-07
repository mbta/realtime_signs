defmodule Signs.Utilities.PredictionsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias Signs.Utilities.SourceConfig

  defmodule FakePredictions do
  end

  defmodule FakeUpdater do
  end

  @sign %Signs.Realtime{
    id: "sign_id",
    text_id: {"TEST", "x"},
    audio_id: {"TEST", ["x"]},
    source_config: {%{sources: []}, %{sources: []}},
    current_content_top: Content.Message.Empty.new(),
    current_content_bottom: Content.Message.Empty.new(),
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    last_departure_engine: FakeDepartures,
    config_engine: Engine.Config,
    alerts_engine: nil,
    current_time_fn: nil,
    sign_updater: FakeUpdater,
    last_update: Timex.now(),
    tick_audit: 240,
    tick_read: 240,
    read_period_seconds: 240
  }

  describe "get_messages" do
    test "when given two source lists, returns earliest result from each" do
      predictions1 = [
        %Predictions.Prediction{
          stop_id: "1",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "70093",
          seconds_until_arrival: 120,
          seconds_until_departure: 180
        },
        %Predictions.Prediction{
          stop_id: "1",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "70093",
          seconds_until_arrival: 240,
          seconds_until_departure: 300
        }
      ]

      predictions2 = [
        %Predictions.Prediction{
          stop_id: "2",
          direction_id: 1,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 120,
          seconds_until_departure: 180
        },
        %Predictions.Prediction{
          stop_id: "2",
          direction_id: 1,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 240,
          seconds_until_departure: 300
        }
      ]

      assert {
               %Content.Message.Predictions{destination: :ashmont, minutes: 2},
               %Content.Message.Predictions{destination: :alewife, minutes: 2}
             } = Signs.Utilities.Predictions.get_messages({predictions1, predictions2}, @sign)
    end

    test "when given one source list, returns earliest two results" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "3",
          direction_id: 1,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 120,
          seconds_until_departure: 180
        },
        %Predictions.Prediction{
          stop_id: "3",
          direction_id: 1,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 500,
          seconds_until_departure: 600
        },
        %Predictions.Prediction{
          stop_id: "4",
          direction_id: 1,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 240,
          seconds_until_departure: 300
        }
      ]

      sign = %{@sign | source_config: %{sources: []}}

      assert {
               %Content.Message.Predictions{destination: :alewife, minutes: 2},
               %Content.Message.Predictions{destination: :alewife, minutes: 4}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end

    test "sorts by arrival or departure depending on which is present" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "arrival_vs_departure_time",
          direction_id: 1,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 240,
          seconds_until_departure: 300
        },
        %Predictions.Prediction{
          stop_id: "arrival_vs_departure_time",
          direction_id: 1,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: nil,
          seconds_until_departure: 480
        }
      ]

      sign = %{@sign | source_config: %{sources: []}}

      assert {
               %Content.Message.Predictions{destination: :alewife, minutes: 4},
               %Content.Message.Predictions{destination: :alewife, minutes: 8}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end

    test "When the train is stopped a long time away, but not quite max time, shows stopped" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "stopped_a_long_time_away",
          direction_id: 0,
          route_id: "Mattapan",
          stopped?: false,
          stops_away: 8,
          boarding_status: "Stopped 8 stop away",
          destination_stop_id: "123",
          seconds_until_arrival: 1100,
          seconds_until_departure: 10
        }
      ]

      sign = %{@sign | source_config: %{sources: []}}

      assert {
               %Content.Message.StoppedTrain{stops_away: 8},
               %Content.Message.Empty{}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end

    test "When the train is stopped a long time away from a terminal, shows max time instead of stopped" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "stopped_a_long_time_away_terminal",
          direction_id: 0,
          route_id: "Mattapan",
          stopped?: false,
          stops_away: 8,
          boarding_status: "Stopped 8 stop away",
          destination_stop_id: "123",
          seconds_until_arrival: 10,
          seconds_until_departure: 2020
        }
      ]

      src = %SourceConfig{
        stop_id: "stopped_a_long_time_away_terminal",
        direction_id: 0,
        terminal?: true,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = %{sources: [src]}
      sign = %{@sign | source_config: config}

      assert {
               %Content.Message.Predictions{destination: :mattapan, minutes: :max_time},
               %Content.Message.Empty{}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end

    test "When the train is stopped a long time away, shows max time instead of stopped" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "stopped_a_long_time_away",
          direction_id: 0,
          route_id: "Mattapan",
          stopped?: false,
          stops_away: 8,
          boarding_status: "Stopped 8 stop away",
          destination_stop_id: "123",
          seconds_until_arrival: 1200,
          seconds_until_departure: 10
        }
      ]

      sign = %{@sign | source_config: %{sources: []}}

      assert {
               %Content.Message.Predictions{destination: :mattapan, minutes: :max_time},
               %Content.Message.Empty{}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end

    test "pads out results if only one prediction" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "7",
          direction_id: 1,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 0,
          seconds_until_departure: 300
        }
      ]

      sign = %{@sign | source_config: %{sources: []}}

      assert {
               %Content.Message.Predictions{},
               %Content.Message.Empty{}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end

    test "pads out results if no predictions" do
      sign = %{@sign | source_config: %{sources: []}}

      assert {
               %Content.Message.Empty{},
               %Content.Message.Empty{}
             } = Signs.Utilities.Predictions.get_messages([], sign)
    end

    test "only the first prediction in a source list can be BRD" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "8",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 0,
          destination_stop_id: "123",
          seconds_until_arrival: 0,
          seconds_until_departure: 90,
          boarding_status: nil
        },
        %Predictions.Prediction{
          stop_id: "8",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 100,
          seconds_until_departure: 120
        }
      ]

      sign = %{@sign | source_config: %{sources: []}}

      assert {
               %Content.Message.Predictions{minutes: :boarding},
               %Content.Message.Predictions{minutes: 2}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end

    test "Returns stopped train message" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "9",
          direction_id: 0,
          route_id: "Red",
          stopped?: true,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 10,
          seconds_until_departure: 100,
          boarding_status: "Stopped 1 stop away"
        }
      ]

      sign = %{@sign | source_config: %{sources: []}}

      assert {
               %Content.Message.StoppedTrain{stops_away: 1},
               %Content.Message.Empty{}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end

    test "Only includes predictions if a departure prediction is present" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "stop_with_nil_departure_prediction",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 10,
          seconds_until_departure: nil
        }
      ]

      sign = %{@sign | source_config: %{sources: []}}

      assert {
               %Content.Message.Empty{},
               %Content.Message.Empty{}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end

    test "Sorts boarding status to the top" do
      # when both are 0 stops away, sorts by time
      predictions1 = [
        %Predictions.Prediction{
          stop_id: "both_brd",
          direction_id: 0,
          route_id: "Green-B",
          stopped?: false,
          stops_away: 0,
          destination_stop_id: "123",
          seconds_until_arrival: 200,
          seconds_until_departure: 250
        },
        %Predictions.Prediction{
          stop_id: "both_brd",
          direction_id: 0,
          route_id: "Green-C",
          stopped?: false,
          stops_away: 0,
          destination_stop_id: "123",
          seconds_until_arrival: 250,
          seconds_until_departure: 300
        }
      ]

      sign = %{@sign | source_config: %{sources: []}}

      assert {
               %Content.Message.Predictions{destination: :boston_college, minutes: :boarding},
               %Content.Message.Predictions{destination: :cleveland_circle, minutes: :boarding}
             } = Signs.Utilities.Predictions.get_messages(predictions1, sign)

      # when second is 0 stops away, sorts first, even if "later"
      predictions2 = [
        %Predictions.Prediction{
          stop_id: "second_brd",
          direction_id: 0,
          route_id: "Green-B",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 200,
          seconds_until_departure: 250
        },
        %Predictions.Prediction{
          stop_id: "second_brd",
          direction_id: 0,
          route_id: "Green-C",
          stopped?: false,
          stops_away: 0,
          destination_stop_id: "123",
          seconds_until_arrival: 250,
          seconds_until_departure: 300
        }
      ]

      assert {
               %Content.Message.Predictions{destination: :cleveland_circle, minutes: :boarding},
               %Content.Message.Predictions{destination: :boston_college, minutes: 3}
             } = Signs.Utilities.Predictions.get_messages(predictions2, sign)

      # when first is 0 stops away, sorts first, even if "later"
      predictions3 = [
        %Predictions.Prediction{
          stop_id: "first_brd",
          direction_id: 0,
          route_id: "Green-B",
          stopped?: false,
          stops_away: 0,
          destination_stop_id: "123",
          seconds_until_arrival: 250,
          seconds_until_departure: 300
        },
        %Predictions.Prediction{
          stop_id: "first_brd",
          direction_id: 0,
          route_id: "Green-C",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 200,
          seconds_until_departure: 250
        }
      ]

      assert {
               %Content.Message.Predictions{destination: :boston_college, minutes: :boarding},
               %Content.Message.Predictions{destination: :cleveland_circle, minutes: 3}
             } = Signs.Utilities.Predictions.get_messages(predictions3, sign)
    end

    test "Does not allow ARR on second line unless platform has multiple berths" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "arr_multi_berth1",
          direction_id: 0,
          route_id: "Green-C",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 15,
          seconds_until_departure: 50
        },
        %Predictions.Prediction{
          stop_id: "arr_multi_berth2",
          direction_id: 0,
          route_id: "Green-D",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 16,
          seconds_until_departure: 50
        }
      ]

      s1 = %SourceConfig{
        stop_id: "arr_multi_berth1",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        routes: nil,
        announce_arriving?: false,
        announce_boarding?: false,
        multi_berth?: true
      }

      s2 = %{s1 | stop_id: "arr_multi_berth2"}

      config = %{sources: [s1, s2]}
      sign = %{@sign | source_config: config}

      assert {
               %Content.Message.Predictions{destination: :cleveland_circle, minutes: :arriving},
               %Content.Message.Predictions{destination: :riverside, minutes: :arriving}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)

      s1 = %{s1 | multi_berth?: false}
      s2 = %{s2 | multi_berth?: false}
      config = %{sources: [s1, s2]}
      sign = %{@sign | source_config: config}

      assert {
               %Content.Message.Predictions{destination: :cleveland_circle, minutes: :arriving},
               %Content.Message.Predictions{destination: :riverside, minutes: 1}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end

    test "Correctly orders BRD predictions between trains mid-trip and those starting their trip" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "multiple_brd_some_first_stop_1",
          direction_id: 0,
          route_id: "Green-D",
          stopped?: false,
          stops_away: 0,
          destination_stop_id: "123",
          seconds_until_arrival: -30,
          seconds_until_departure: 60
        },
        %Predictions.Prediction{
          stop_id: "multiple_brd_some_first_stop_1",
          direction_id: 0,
          route_id: "Green-D",
          stopped?: false,
          stops_away: 0,
          destination_stop_id: "123",
          seconds_until_arrival: -15,
          seconds_until_departure: 75
        },
        %Predictions.Prediction{
          stop_id: "multiple_brd_some_first_stop_2",
          direction_id: 0,
          route_id: "Green-B",
          stopped?: false,
          stops_away: 0,
          destination_stop_id: "123",
          seconds_until_arrival: nil,
          seconds_until_departure: 60
        }
      ]

      sign = %{@sign | source_config: %{sources: []}}

      assert {
               %Content.Message.Predictions{destination: :riverside, minutes: :boarding},
               %Content.Message.Predictions{destination: :boston_college, minutes: :boarding}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end

    test "doesn't sort 0 stops away to first for terminals when another departure is sooner" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "terminal_dont_sort_0_stops_first",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "70105",
          seconds_until_arrival: nil,
          seconds_until_departure: 120,
          trip_id: "123"
        },
        %Predictions.Prediction{
          stop_id: "terminal_dont_sort_0_stops_first",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 0,
          destination_stop_id: "70093",
          seconds_until_arrival: nil,
          seconds_until_departure: 240,
          trip_id: "123"
        }
      ]

      s = %SourceConfig{
        stop_id: "terminal_dont_sort_0_stops_first",
        direction_id: 0,
        terminal?: true,
        platform: nil,
        routes: nil,
        announce_arriving?: false,
        announce_boarding?: true
      }

      config = %{sources: [s]}
      sign = %{@sign | source_config: config}

      assert {
               %Content.Message.Predictions{destination: :braintree, minutes: 1},
               %Content.Message.Predictions{destination: :ashmont, minutes: 3}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end

    test "properly handles case where destination can't be determined" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "indeterminate_destination",
          direction_id: 0,
          route_id: "Not a Valid Route",
          stopped?: false,
          stops_away: 0,
          destination_stop_id: "Not a Valid Stop ID",
          seconds_until_arrival: nil,
          seconds_until_departure: 240,
          trip_id: "123"
        }
      ]

      sign = %{@sign | source_config: %{sources: []}}

      assert Signs.Utilities.Predictions.get_messages(predictions, sign) ==
               {%Content.Message.Empty{}, %Content.Message.Empty{}}
    end
  end

  describe "get_passthrough_train_audio/1" do
    test "returns appropriate audio structs for multi-source sign" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "passthrough_trains",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 4,
          destination_stop_id: "70105",
          seconds_until_arrival: nil,
          seconds_until_departure: nil,
          seconds_until_passthrough: 30,
          trip_id: "123"
        }
      ]

      assert Signs.Utilities.Predictions.get_passthrough_train_audio({predictions, []}) == [
               %Content.Audio.Passthrough{
                 destination: :braintree,
                 route_id: "Red",
                 trip_id: "123"
               }
             ]
    end

    test "returns appropriate audio structs for single-source sign" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "passthrough_trains",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 4,
          destination_stop_id: "70105",
          seconds_until_arrival: nil,
          seconds_until_departure: nil,
          seconds_until_passthrough: 30,
          trip_id: "123"
        },
        %Predictions.Prediction{
          stop_id: "passthrough_trains",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 4,
          destination_stop_id: "70093",
          seconds_until_arrival: nil,
          seconds_until_departure: nil,
          seconds_until_passthrough: 60,
          trip_id: "123"
        }
      ]

      assert Signs.Utilities.Predictions.get_passthrough_train_audio(predictions) == [
               %Content.Audio.Passthrough{
                 destination: :braintree,
                 trip_id: "123",
                 route_id: "Red"
               }
             ]
    end

    test "handles \"Southbound\" headsign" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "passthrough_trains_southbound_red_line_destination",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 4,
          destination_stop_id: "70083",
          seconds_until_arrival: nil,
          seconds_until_departure: nil,
          seconds_until_passthrough: 30,
          trip_id: "123"
        }
      ]

      assert Signs.Utilities.Predictions.get_passthrough_train_audio(predictions) ==
               [
                 %Content.Audio.Passthrough{
                   destination: :ashmont,
                   trip_id: "123",
                   route_id: "Red"
                 }
               ]
    end

    test "handles case where headsign can't be determined" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "passthrough_trains_bad_destination",
          direction_id: 1,
          route_id: "Foo",
          stopped?: false,
          stops_away: 4,
          destination_stop_id: "bar",
          seconds_until_arrival: nil,
          seconds_until_departure: nil,
          seconds_until_passthrough: 60,
          trip_id: "123"
        }
      ]

      log =
        capture_log([level: :info], fn ->
          assert Signs.Utilities.Predictions.get_passthrough_train_audio(predictions) == []
        end)

      assert log =~ "no_passthrough_audio_for_prediction"
    end

    test "prefers showing distinct destinations when present" do
      predictions = [
        %Predictions.Prediction{
          stop_id: "multiple_destinations",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "70085",
          seconds_until_arrival: 120,
          seconds_until_departure: 180
        },
        %Predictions.Prediction{
          stop_id: "multiple_destinations",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "70085",
          seconds_until_arrival: 500,
          seconds_until_departure: 600
        },
        %Predictions.Prediction{
          stop_id: "multiple_destinations",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "70099",
          seconds_until_arrival: 700,
          seconds_until_departure: 800
        }
      ]

      sign = %{@sign | source_config: %{sources: []}}

      assert {
               %Content.Message.Predictions{destination: :ashmont},
               %Content.Message.Predictions{destination: :braintree}
             } = Signs.Utilities.Predictions.get_messages(predictions, sign)
    end
  end
end
