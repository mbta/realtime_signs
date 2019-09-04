defmodule Signs.Utilities.HeadwaysTest do
  use ExUnit.Case

  defmodule FakeAlerts do
    def max_stop_status(["suspended"], _routes), do: :suspension_closed_station
    def max_stop_status(["suspended_transfer"], _routes), do: :suspension_transfer_station
    def max_stop_status(["shuttles"], _routes), do: :shuttles_closed_station
    def max_stop_status(["closure"], _routes), do: :station_closure
    def max_stop_status(_stops, ["Green-B"]), do: :alert_along_route
    def max_stop_status(_stops, _routes), do: :none
  end

  defmodule FakeLastDepartures do
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

  @sign %Signs.Realtime{
    id: "sign_id",
    text_id: {"TEST", "x"},
    audio_id: {"TEST", ["x"]},
    source_config: {[], []},
    current_content_top: {nil, Content.Message.Empty.new()},
    current_content_bottom: {nil, Content.Message.Empty.new()},
    prediction_engine: FakePredictions,
    headway_engine: FakeHeadways,
    last_departure_engine: FakeLastDepartures,
    alerts_engine: FakeAlerts,
    bridge_engine: nil,
    sign_updater: FakeUpdater,
    tick_bottom: 130,
    tick_top: 130,
    tick_read: 240,
    expiration_seconds: 130,
    read_period_seconds: 240
  }

  @spec source_config_for_stop_id(String.t()) :: %Signs.Utilities.SourceConfig{}
  defp source_config_for_stop_id(stop_id) do
    %Signs.Utilities.SourceConfig{
      stop_id: stop_id,
      routes: ["Red"],
      headway_direction_name: "Southbound",
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
      current_time = Timex.shift(FakeLastDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(@sign, current_time) ==
               {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}
    end

    test "generates top and bottom messages to display the headway at a single-source stop" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("a")]}
      }

      current_time = Timex.shift(FakeLastDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("a"),
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_config_for_stop_id("a"),
                 %Content.Message.Headways.Bottom{
                   range: {2, 8},
                   prev_departure_mins: 5
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

      current_time = Timex.shift(FakeLastDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_with_headway,
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_with_headway,
                 %Content.Message.Headways.Bottom{
                   range: {2, 8},
                   prev_departure_mins: 5
                 }}}
    end

    test "increases the headways if there are alerts on the route" do
      source_config = %{source_config_for_stop_id("a") | routes: ["Green-B"]}

      sign = %{
        @sign
        | source_config: {[source_config]}
      }

      current_time = Timex.shift(FakeLastDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config,
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_config,
                 %Content.Message.Headways.Bottom{
                   range: {3, 11},
                   prev_departure_mins: 5
                 }}}
    end

    test "increases the headways if there are alerts on the route and it only gets a bottom end of the range" do
      source_config = %{source_config_for_stop_id("h") | routes: ["Green-B"]}

      sign = %{
        @sign
        | source_config: {[source_config]}
      }

      current_time = Timex.shift(FakeLastDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config,
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_config,
                 %Content.Message.Headways.Bottom{
                   range: {3, nil},
                   prev_departure_mins: 5
                 }}}
    end

    test "increases the headways if there are alerts on the route and it only gets a top end of the range" do
      source_config = %{source_config_for_stop_id("g") | routes: ["Green-B"]}

      sign = %{
        @sign
        | source_config: {[source_config]}
      }

      current_time = Timex.shift(FakeLastDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config,
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_config,
                 %Content.Message.Headways.Bottom{
                   range: {nil, 7},
                   prev_departure_mins: 5
                 }}}
    end

    test "generates blank messages to display when no headway information present" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("b")]}
      }

      current_time = Timex.shift(FakeLastDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("b"), %Content.Message.Empty{}},
                {source_config_for_stop_id("b"), %Content.Message.Empty{}}}
    end

    test "generates blank messages for {nil, nil} headways" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("c")]}
      }

      current_time = Timex.shift(FakeLastDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("c"), %Content.Message.Empty{}},
                {source_config_for_stop_id("c"), %Content.Message.Empty{}}}
    end

    test "generates blank messages to display more than one headway earlier than the first departure of the day" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("d")]}
      }

      current_time = Timex.shift(FakeLastDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("d"), %Content.Message.Empty{}},
                {source_config_for_stop_id("d"), %Content.Message.Empty{}}}
    end

    test "generates a headway message to display immediately before the first departure of the day" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("e")]}
      }

      current_time = Timex.shift(FakeLastDepartures.test_departure_time(), minutes: 5)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("e"),
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_config_for_stop_id("e"),
                 %Content.Message.Headways.Bottom{
                   range: {1, 5},
                   prev_departure_mins: nil
                 }}}
    end

    test "when last departure was recent (<5 seconds), treat it as 0" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("a")]}
      }

      current_time = Timex.shift(FakeLastDepartures.test_departure_time(), seconds: 3)

      assert Signs.Utilities.Headways.get_messages(sign, current_time) ==
               {{source_config_for_stop_id("a"),
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_config_for_stop_id("a"),
                 %Content.Message.Headways.Bottom{
                   range: {2, 8},
                   prev_departure_mins: 0
                 }}}
    end
  end
end
