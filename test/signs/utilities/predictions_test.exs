defmodule Signs.Utilities.PredictionsTest do
  use ExUnit.Case
  alias Signs.Utilities.SourceConfig

  defmodule FakePredictions do
    def for_stop("1", 0) do
      [
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
    end

    def for_stop("2", 1) do
      [
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
    end

    def for_stop("3", 1) do
      [
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
        }
      ]
    end

    def for_stop("4", 1) do
      [
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
    end

    def for_stop("arrival_vs_departure_time", 1) do
      [
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
          seconds_until_departure: 600
        }
      ]
    end

    def for_stop("7", 1) do
      [
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
    end

    def for_stop("8", 0) do
      [
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
    end

    def for_stop("9", 0) do
      [
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
    end

    def for_stop("10", 0) do
      [
        %Predictions.Prediction{
          stop_id: "10",
          direction_id: 0,
          route_id: "Red",
          stopped?: true,
          stops_away: 0,
          destination_stop_id: "123",
          seconds_until_arrival: 10,
          seconds_until_departure: 100,
          boarding_status: "Stopped at station"
        },
        %Predictions.Prediction{
          stop_id: "10",
          direction_id: 0,
          route_id: "Red",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 360,
          seconds_until_departure: 400
        }
      ]
    end

    def for_stop("stop_with_nil_departure_prediction", 0) do
      [
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
    end

    def for_stop("filterable_by_route", 0) do
      [
        %Predictions.Prediction{
          stop_id: "filterable_by_route",
          direction_id: 0,
          route_id: "Green-B",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 100,
          seconds_until_departure: 150
        },
        %Predictions.Prediction{
          stop_id: "filterable_by_route",
          direction_id: 0,
          route_id: "Green-D",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 200,
          seconds_until_departure: 250
        }
      ]
    end

    def for_stop("both_brd", 0) do
      # when both are 0 stops away, sorts by time
      [
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
    end

    def for_stop("second_brd", 0) do
      # when second is 0 stops away, sorts first, even if "later"
      [
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
    end

    def for_stop("first_brd", 0) do
      # when first is 0 stops away, sorts first, even if "later"
      [
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
    end

    def for_stop("arr_multi_berth1", 0) do
      [
        %Predictions.Prediction{
          stop_id: "arr_multi_berth1",
          direction_id: 0,
          route_id: "Green-C",
          stopped?: false,
          stops_away: 1,
          destination_stop_id: "123",
          seconds_until_arrival: 15,
          seconds_until_departure: 50
        }
      ]
    end

    def for_stop("arr_multi_berth2", 0) do
      [
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
    end

    def for_stop("stopped_a_long_time_away", 0) do
      [
        %Predictions.Prediction{
          stop_id: "stopped_a_long_time_away",
          direction_id: 0,
          route_id: "Mattapan",
          stopped?: false,
          stops_away: 8,
          boarding_status: "Stopped 8 stop away",
          destination_stop_id: "123",
          seconds_until_arrival: 2000,
          seconds_until_departure: 10
        }
      ]
    end

    def for_stop("stopped_a_long_time_away_terminal", 0) do
      [
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
    end

    def for_stop(_stop_id, _direction_id) do
      []
    end
  end

  defmodule FakeUpdater do
  end

  @sign %Signs.Realtime{
    id: "sign_id",
    text_id: {"TEST", "x"},
    audio_id: {"TEST", ["x"]},
    source_config: {[], []},
    current_content_top: {nil, Content.Message.Empty.new()},
    current_content_bottom: {nil, Content.Message.Empty.new()},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    alerts_engine: nil,
    sign_updater: FakeUpdater,
    tick_bottom: 130,
    tick_top: 130,
    tick_read: 240,
    expiration_seconds: 130,
    read_period_seconds: 240
  }

  describe "get_messages/2" do
    test "when given two source lists, returns earliest result from each" do
      s1 = %SourceConfig{
        stop_id: "1",
        headway_direction_name: "Mattapan",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      s2 = %SourceConfig{
        stop_id: "2",
        headway_direction_name: "Mattapan",
        direction_id: 1,
        terminal?: false,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = {[s1], [s2]}
      sign = %{@sign | source_config: config}

      assert {
               {^s1, %Content.Message.Predictions{headsign: "Ashmont", minutes: 2}},
               {^s2, %Content.Message.Predictions{headsign: "Alewife", minutes: 2}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end

    test "when given one source list, returns earliest two results" do
      s1 = %SourceConfig{
        stop_id: "3",
        headway_direction_name: "Mattapan",
        direction_id: 1,
        terminal?: false,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      s2 = %SourceConfig{
        stop_id: "4",
        headway_direction_name: "Mattapan",
        direction_id: 1,
        terminal?: false,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = {[s1, s2]}
      sign = %{@sign | source_config: config}

      assert {
               {^s1, %Content.Message.Predictions{headsign: "Alewife", minutes: 2}},
               {^s2, %Content.Message.Predictions{headsign: "Alewife", minutes: 4}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end

    test "sorts by arrival or departure depending on which is present" do
      src = %SourceConfig{
        stop_id: "arrival_vs_departure_time",
        headway_direction_name: "Mattapan",
        direction_id: 1,
        terminal?: false,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = {[src]}
      sign = %{@sign | source_config: config}

      assert {
               {^src, %Content.Message.Predictions{headsign: "Alewife", minutes: 4}},
               {^src, %Content.Message.Predictions{headsign: "Alewife", minutes: 10}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end

    test "When the train is stopped a long time away from a terminal, shows 30 minutes instead of stopped" do
      src = %SourceConfig{
        stop_id: "stopped_a_long_time_away_terminal",
        headway_direction_name: "Mattapan",
        direction_id: 0,
        terminal?: true,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = {[src]}
      sign = %{@sign | source_config: config}

      assert {
               {^src, %Content.Message.Predictions{headsign: "Mattapan", minutes: :max_time}},
               {nil, %Content.Message.Empty{}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end

    test "When the train is stopped a long time away, shows 30 minutes instead of stopped" do
      src = %SourceConfig{
        stop_id: "stopped_a_long_time_away",
        headway_direction_name: "Mattapan",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = {[src]}
      sign = %{@sign | source_config: config}

      assert {
               {^src, %Content.Message.Predictions{headsign: "Mattapan", minutes: :max_time}},
               {nil, %Content.Message.Empty{}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end

    test "pads out results if only one prediction" do
      s = %SourceConfig{
        stop_id: "7",
        headway_direction_name: "Mattapan",
        direction_id: 1,
        terminal?: false,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = {[s]}
      sign = %{@sign | source_config: config}

      assert {
               {^s, %Content.Message.Predictions{}},
               {nil, %Content.Message.Empty{}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end

    test "pads out results if no predictions" do
      s = %SourceConfig{
        stop_id: "n/a",
        headway_direction_name: "Mattapan",
        direction_id: 1,
        terminal?: false,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = {[s]}
      sign = %{@sign | source_config: config}

      assert {
               {nil, %Content.Message.Empty{}},
               {nil, %Content.Message.Empty{}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end

    test "only the first prediction in a source list can be BRD" do
      s = %SourceConfig{
        stop_id: "8",
        headway_direction_name: "Mattapan",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = {[s]}
      sign = %{@sign | source_config: config}

      assert {
               {^s, %Content.Message.Predictions{minutes: :boarding}},
               {^s, %Content.Message.Predictions{minutes: 2}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end

    test "Returns stopped train message" do
      s = %SourceConfig{
        stop_id: "9",
        headway_direction_name: "Mattapan",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = {[s]}
      sign = %{@sign | source_config: config}

      assert {
               {^s, %Content.Message.StoppedTrain{stops_away: 1}},
               {nil, %Content.Message.Empty{}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end

    test "Returns regular prediction message if train is stopped at station" do
      s = %SourceConfig{
        stop_id: "10",
        headway_direction_name: "Mattapan",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = {[s]}
      sign = %{@sign | source_config: config}

      assert {
               {^s, %Content.Message.Predictions{minutes: :boarding}},
               {^s, %Content.Message.Predictions{minutes: 6}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end

    test "Only includes predictions if a departure prediction is present" do
      s = %SourceConfig{
        stop_id: "stop_with_nil_departure_prediction",
        headway_direction_name: "Mattapan",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = {[s]}
      sign = %{@sign | source_config: config}

      assert {
               {nil, %Content.Message.Empty{}},
               {nil, %Content.Message.Empty{}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end

    test "Filters by route if present" do
      s1 = %SourceConfig{
        stop_id: "filterable_by_route",
        headway_direction_name: "Mattapan",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        routes: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      s2 = %{s1 | routes: ["Green-D"]}

      config1 = {[s1]}
      config2 = {[s2]}

      sign1 = %{@sign | source_config: config1}
      sign2 = %{@sign | source_config: config2}

      assert {
               {^s1, %Content.Message.Predictions{headsign: "Boston Col"}},
               {^s1, %Content.Message.Predictions{headsign: "Riverside"}}
             } = Signs.Utilities.Predictions.get_messages(sign1)

      assert {
               {^s2, %Content.Message.Predictions{headsign: "Riverside"}},
               {nil, %Content.Message.Empty{}}
             } = Signs.Utilities.Predictions.get_messages(sign2)
    end

    test "Sorts boarding status to the top" do
      s = %SourceConfig{
        stop_id: "both_brd",
        headway_direction_name: "Mattapan",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        routes: nil,
        announce_arriving?: false,
        announce_boarding?: false
      }

      config = {[s]}
      sign = %{@sign | source_config: config}

      assert {
               {^s, %Content.Message.Predictions{headsign: "Boston Col", minutes: :boarding}},
               {^s, %Content.Message.Predictions{headsign: "Clvlnd Cir", minutes: :boarding}}
             } = Signs.Utilities.Predictions.get_messages(sign)

      s = %{s | stop_id: "second_brd"}
      config = {[s]}
      sign = %{sign | source_config: config}

      assert {
               {^s, %Content.Message.Predictions{headsign: "Clvlnd Cir", minutes: :boarding}},
               {^s, %Content.Message.Predictions{headsign: "Boston Col", minutes: 3}}
             } = Signs.Utilities.Predictions.get_messages(sign)

      s = %{s | stop_id: "first_brd"}
      config = {[s]}
      sign = %{sign | source_config: config}

      assert {
               {^s, %Content.Message.Predictions{headsign: "Boston Col", minutes: :boarding}},
               {^s, %Content.Message.Predictions{headsign: "Clvlnd Cir", minutes: 3}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end

    test "Does not allow ARR on second line unless platform has multiple berths" do
      s1 = %SourceConfig{
        stop_id: "arr_multi_berth1",
        headway_direction_name: "Mattapan",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        routes: nil,
        announce_arriving?: false,
        announce_boarding?: false,
        multi_berth?: true
      }

      s2 = %{s1 | stop_id: "arr_multi_berth2"}

      config = {[s1, s2]}
      sign = %{@sign | source_config: config}

      assert {
               {^s1, %Content.Message.Predictions{headsign: "Clvlnd Cir", minutes: :arriving}},
               {^s2, %Content.Message.Predictions{headsign: "Riverside", minutes: :arriving}}
             } = Signs.Utilities.Predictions.get_messages(sign)

      s1 = %{s1 | multi_berth?: false}
      s2 = %{s2 | multi_berth?: false}
      config = {[s1, s2]}
      sign = %{@sign | source_config: config}

      assert {
               {^s1, %Content.Message.Predictions{headsign: "Clvlnd Cir", minutes: :arriving}},
               {^s2, %Content.Message.Predictions{headsign: "Riverside", minutes: 1}}
             } = Signs.Utilities.Predictions.get_messages(sign)
    end
  end
end
