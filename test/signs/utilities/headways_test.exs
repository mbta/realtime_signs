defmodule Signs.Utilities.HeadwaysTest do
  use ExUnit.Case

  defmodule FakeAlerts do
    def max_stop_status(_stops, _routes), do: :none
  end

  defmodule FakeDepartures do
    @test_departure_time Timex.to_datetime(~N[2019-08-29 15:41:31], "America/New_York")

    def get_last_departure(_) do
      @test_departure_time
    end

    def test_departure_time() do
      @test_departure_time
    end
  end

  defmodule FakeHeadways do
    def get_headways("a") do
      {2, 8}
    end

    def get_headways("b") do
      :none
    end

    def get_headways("c") do
      {nil, nil}
    end

    def get_headways("d") do
      {:first_departure, {1, 5}, DateTime.utc_now() |> Timex.shift(minutes: 10)}
    end

    def get_headways("e") do
      {:first_departure, {1, 5}, DateTime.utc_now()}
    end

    def get_headways("f") do
      {nil, nil}
    end

    def get_headways("g") do
      {nil, 5}
    end

    def get_headways("h") do
      {2, nil}
    end
  end

  defmodule FakeHeadwayConfigEngine do
    def headway_config("first_dep_test", _time) do
      %Engine.Config.Headway{headway_id: "id", range_low: 7, range_high: 11}
    end

    def headway_config("config_test", _time) do
      %Engine.Config.Headway{headway_id: "id", range_low: 9, range_high: 13}
    end

    def headway_config(_headway_group, _time) do
      nil
    end
  end

  @sign %Signs.Realtime{
    id: "sign_id",
    headway_group: "headway_group",
    text_id: {"TEST", "x"},
    audio_id: {"TEST", ["x"]},
    source_config: {[], []},
    current_content_top: {nil, Content.Message.Empty.new()},
    current_content_bottom: {nil, Content.Message.Empty.new()},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    last_departure_engine: FakeDepartures,
    config_engine: Engine.Config,
    alerts_engine: FakeAlerts,
    sign_updater: FakeUpdater,
    tick_bottom: 130,
    tick_top: 130,
    tick_audit: 240,
    tick_read: 240,
    expiration_seconds: 130,
    read_period_seconds: 240
  }

  @spec source_config_for_stop_id(String.t()) :: %Signs.Utilities.SourceConfig{}
  defp source_config_for_stop_id(stop_id) do
    %Signs.Utilities.SourceConfig{
      stop_id: stop_id,
      routes: ["Red"],
      headway_destination: :southbound,
      direction_id: 0,
      platform: nil,
      terminal?: false,
      announce_arriving?: false,
      announce_boarding?: false,
      multi_berth?: false
    }
  end

  describe "get_messages/2" do
    test "generates blank messages when the source config has multiple sources and the sign has no headway_stop_id" do
      current_time = Timex.shift(FakeDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(@sign, current_time) ==
               {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}
    end

    test "generates top and bottom messages to display the headway at a single-source stop" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("a")]}
      }

      current_time = Timex.shift(FakeDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("a"),
                 %Content.Message.Headways.Top{destination: :southbound, vehicle_type: :train}},
                {source_config_for_stop_id("a"),
                 %Content.Message.Headways.Bottom{
                   range: {2, 8},
                   prev_departure_mins: nil
                 }}}
    end

    test "generates top and bottom messages to display the headway for a sign with headway_stop_id" do
      source_with_headway = %{source_config_for_stop_id("a") | source_for_headway?: true}

      sign = %{
        @sign
        | source_config:
            {[
               source_config_for_stop_id("f"),
               source_with_headway,
               source_config_for_stop_id("c")
             ]}
      }

      current_time = Timex.shift(FakeDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_with_headway,
                 %Content.Message.Headways.Top{destination: :southbound, vehicle_type: :train}},
                {source_with_headway,
                 %Content.Message.Headways.Bottom{
                   range: {2, 8},
                   prev_departure_mins: nil
                 }}}
    end

    test "generates headway range based on headway config" do
      source_with_headway = %{source_config_for_stop_id("a") | source_for_headway?: true}

      sign = %{
        @sign
        | source_config:
            {[
               source_config_for_stop_id("f"),
               source_with_headway,
               source_config_for_stop_id("c")
             ]},
          config_engine: FakeHeadwayConfigEngine,
          headway_group: "config_test"
      }

      current_time = Timex.shift(FakeDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_with_headway,
                 %Content.Message.Headways.Top{destination: :southbound, vehicle_type: :train}},
                {source_with_headway,
                 %Content.Message.Headways.Bottom{
                   range: {9, 13},
                   prev_departure_mins: nil
                 }}}
    end

    test "generates blank messages to display when no headway information present" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("b")]}
      }

      current_time = Timex.shift(FakeDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("b"), %Content.Message.Empty{}},
                {source_config_for_stop_id("b"), %Content.Message.Empty{}}}
    end

    test "generates blank messages for {nil, nil} headways" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("c")]}
      }

      current_time = Timex.shift(FakeDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("c"), %Content.Message.Empty{}},
                {source_config_for_stop_id("c"), %Content.Message.Empty{}}}
    end

    test "generates blank messages to display more than one headway earlier than the first departure of the day" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("d")]}
      }

      current_time = Timex.shift(FakeDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("d"), %Content.Message.Empty{}},
                {source_config_for_stop_id("d"), %Content.Message.Empty{}}}
    end

    test "generates a headway message to display immediately before the first departure of the day" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("e")]}
      }

      current_time = Timex.shift(FakeDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("e"),
                 %Content.Message.Headways.Top{destination: :southbound, vehicle_type: :train}},
                {source_config_for_stop_id("e"),
                 %Content.Message.Headways.Bottom{
                   range: {1, 5},
                   prev_departure_mins: nil
                 }}}
    end

    test "generates a headway message to display before first departure, from headway config" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("e")]},
          headway_group: "first_dep_test",
          config_engine: FakeHeadwayConfigEngine
      }

      current_time = Timex.shift(FakeDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("e"),
                 %Content.Message.Headways.Top{destination: :southbound, vehicle_type: :train}},
                {source_config_for_stop_id("e"),
                 %Content.Message.Headways.Bottom{
                   range: {7, 11},
                   prev_departure_mins: nil
                 }}}
    end

    test "respects headway_stop_id" do
      sign = %{@sign | headway_stop_id: "a", source_config: {[source_config_for_stop_id("c")]}}

      current_time = FakeDepartures.test_departure_time()

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("c"),
                 %Content.Message.Headways.Top{destination: :southbound, vehicle_type: :train}},
                {source_config_for_stop_id("c"),
                 %Content.Message.Headways.Bottom{
                   range: {2, 8},
                   prev_departure_mins: nil
                 }}}
    end
  end
end
