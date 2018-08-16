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
          destination_stop_id: "70093",
          seconds_until_arrival: 120,
          seconds_until_departure: 180
        },
        %Predictions.Prediction{
          stop_id: "1",
          direction_id: 0,
          route_id: "Red",
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
          destination_stop_id: "123",
          seconds_until_arrival: 120,
          seconds_until_departure: 180
        },
        %Predictions.Prediction{
          stop_id: "2",
          direction_id: 1,
          route_id: "Red",
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
          destination_stop_id: "123",
          seconds_until_arrival: 120,
          seconds_until_departure: 180
        },
        %Predictions.Prediction{
          stop_id: "3",
          direction_id: 1,
          route_id: "Red",
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
          destination_stop_id: "123",
          seconds_until_arrival: 240,
          seconds_until_departure: 300
        }
      ]
    end

    def for_stop("5", 1) do
      [
        %Predictions.Prediction{
          stop_id: "5",
          direction_id: 1,
          route_id: "Red",
          destination_stop_id: "123",
          seconds_until_arrival: 240,
          seconds_until_departure: 300
        },
        %Predictions.Prediction{
          stop_id: "5",
          direction_id: 1,
          route_id: "Red",
          destination_stop_id: "123",
          seconds_until_arrival: 500,
          seconds_until_departure: 600
        }
      ]
    end

    def for_stop("6", 1) do
      [
        %Predictions.Prediction{
          stop_id: "6",
          direction_id: 1,
          route_id: "Red",
          destination_stop_id: "123",
          seconds_until_arrival: 0,
          seconds_until_departure: 300
        }
      ]
    end

    def for_stop("7", 1) do
      [
        %Predictions.Prediction{
          stop_id: "7",
          direction_id: 1,
          route_id: "Red",
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
          destination_stop_id: "123",
          seconds_until_arrival: 30,
          seconds_until_departure: 90
        },
        %Predictions.Prediction{
          stop_id: "8",
          direction_id: 0,
          route_id: "Red",
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
          destination_stop_id: "123",
          seconds_until_arrival: 10,
          seconds_until_departure: 100,
          boarding_status: "Stopped 1 stop away"
        }
      ]
    end

    def for_stop(_stop_id, _direction_id) do
      []
    end

    def stopped_at?("8"), do: true
    def stopped_at?(_stop_id), do: false
  end

  defmodule FakeUpdater do
  end

  @sign %Signs.Realtime{
    id: "sign_id",
    pa_ess_id: {"TEST", "x"},
    source_config: {[], []},
    current_content_top: {nil, Content.Message.Empty.new()},
    current_content_bottom: {nil, Content.Message.Empty.new()},
    prediction_engine: FakePredictions,
    sign_updater: FakeUpdater,
    tick_bottom: 130,
    tick_top: 130,
    tick_read: 240,
    expiration_seconds: 130,
    read_period_seconds: 240
  }

  describe "get_messages/2" do
    test "returns empty messages if sign is not enabled" do
      assert Signs.Utilities.Predictions.get_messages(@sign, false) ==
               {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
    end

    test "when given two source lists, returns earliest result from each" do
      s1 = %SourceConfig{
        stop_id: "1",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        announce_arriving?: false
      }

      s2 = %SourceConfig{
        stop_id: "2",
        direction_id: 1,
        terminal?: false,
        platform: nil,
        announce_arriving?: false
      }

      config = {[s1], [s2]}
      sign = %{@sign | source_config: config}

      assert {
               {^s1, %Content.Message.Predictions{headsign: "Ashmont", minutes: 2}},
               {^s2, %Content.Message.Predictions{headsign: "Alewife", minutes: 2}}
             } = Signs.Utilities.Predictions.get_messages(sign, true)
    end

    test "when given one source list, returns earliest two results" do
      s1 = %SourceConfig{
        stop_id: "3",
        direction_id: 1,
        terminal?: false,
        platform: nil,
        announce_arriving?: false
      }

      s2 = %SourceConfig{
        stop_id: "4",
        direction_id: 1,
        terminal?: false,
        platform: nil,
        announce_arriving?: false
      }

      config = {[s1, s2]}
      sign = %{@sign | source_config: config}

      assert {
               {^s1, %Content.Message.Predictions{headsign: "Alewife", minutes: 2}},
               {^s2, %Content.Message.Predictions{headsign: "Alewife", minutes: 4}}
             } = Signs.Utilities.Predictions.get_messages(sign, true)
    end

    test "sorts by arrival and departure depending on whether source is a terminal" do
      s1 = %SourceConfig{
        stop_id: "5",
        direction_id: 1,
        terminal?: false,
        platform: nil,
        announce_arriving?: false
      }

      s2 = %SourceConfig{
        stop_id: "6",
        direction_id: 1,
        terminal?: true,
        platform: nil,
        announce_arriving?: false
      }

      config = {[s1, s2]}
      sign = %{@sign | source_config: config}

      assert {
               {^s1, %Content.Message.Predictions{headsign: "Alewife", minutes: 4}},
               {^s2, %Content.Message.Predictions{headsign: "Alewife", minutes: 5}}
             } = Signs.Utilities.Predictions.get_messages(sign, true)
    end

    test "pads out results if only one prediction" do
      s = %SourceConfig{
        stop_id: "7",
        direction_id: 1,
        terminal?: false,
        platform: nil,
        announce_arriving?: false
      }

      config = {[s]}
      sign = %{@sign | source_config: config}

      assert {
               {^s, %Content.Message.Predictions{}},
               {nil, %Content.Message.Empty{}}
             } = Signs.Utilities.Predictions.get_messages(sign, true)
    end

    test "pads out results if no predictions" do
      s = %SourceConfig{
        stop_id: "n/a",
        direction_id: 1,
        terminal?: false,
        platform: nil,
        announce_arriving?: false
      }

      config = {[s]}
      sign = %{@sign | source_config: config}

      assert {
               {nil, %Content.Message.Empty{}},
               {nil, %Content.Message.Empty{}}
             } = Signs.Utilities.Predictions.get_messages(sign, true)
    end

    test "only the first prediction in a source list can be BRD" do
      s = %SourceConfig{
        stop_id: "8",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        announce_arriving?: false
      }

      config = {[s]}
      sign = %{@sign | source_config: config}

      assert {
               {^s, %Content.Message.Predictions{minutes: :boarding}},
               {^s, %Content.Message.Predictions{minutes: 2}}
             } = Signs.Utilities.Predictions.get_messages(sign, true)
    end

    test "Returns stopped train message if enabled" do
      old_env = Application.get_env(:realtime_signs, :stops_away_enabled?)
      Application.put_env(:realtime_signs, :stops_away_enabled?, true)
      on_exit(fn -> Application.put_env(:realtime_signs, :stops_away_enabled?, old_env) end)

      s = %SourceConfig{
        stop_id: "9",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        announce_arriving?: false
      }

      config = {[s]}
      sign = %{@sign | source_config: config}

      assert {
               {^s, %Content.Message.StoppedTrain{stops_away: 1}},
               {nil, %Content.Message.Empty{}}
             } = Signs.Utilities.Predictions.get_messages(sign, true)
    end

    test "Does not return stopped train message if not enabled" do
      old_env = Application.get_env(:realtime_signs, :stops_away_enabled?)
      Application.put_env(:realtime_signs, :stops_away_enabled?, false)
      on_exit(fn -> Application.put_env(:realtime_signs, :stops_away_enabled?, old_env) end)

      s = %SourceConfig{
        stop_id: "9",
        direction_id: 0,
        terminal?: false,
        platform: nil,
        announce_arriving?: false
      }

      config = {[s]}
      sign = %{@sign | source_config: config}

      assert {
               {^s, %Content.Message.Predictions{}},
               {nil, %Content.Message.Empty{}}
             } = Signs.Utilities.Predictions.get_messages(sign, true)
    end
  end
end
