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

  describe "get_messages/1" do
    test "generates blank messages when the source config has multiple sources and the sign has no headway_stop_id" do
      assert Signs.Utilities.Headways.get_messages(@sign) ==
               {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}
    end

    test "generates top and bottom messages to display the headway at a single-source stop" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("a")]}
      }

      assert Signs.Utilities.Headways.get_messages(sign) ==
               {{source_config_for_stop_id("a"),
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_config_for_stop_id("a"), %Content.Message.Headways.Bottom{range: {2, 8}}}}
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

      assert Signs.Utilities.Headways.get_messages(sign) ==
               {{source_with_headway,
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_with_headway, %Content.Message.Headways.Bottom{range: {2, 8}}}}
    end

    test "increases the headways if there are alerts on the route" do
      source_config = %{source_config_for_stop_id("a") | routes: ["Green-B"]}

      sign = %{
        @sign
        | source_config: {[source_config]}
      }

      assert Signs.Utilities.Headways.get_messages(sign) ==
               {{source_config,
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_config, %Content.Message.Headways.Bottom{range: {3, 11}}}}
    end

    test "increases the headways if there are alerts on the route and it only gets a bottom end of the range" do
      source_config = %{source_config_for_stop_id("h") | routes: ["Green-B"]}

      sign = %{
        @sign
        | source_config: {[source_config]}
      }

      assert Signs.Utilities.Headways.get_messages(sign) ==
               {{source_config,
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_config, %Content.Message.Headways.Bottom{range: {3, nil}}}}
    end

    test "increases the headways if there are alerts on the route and it only gets a top end of the range" do
      source_config = %{source_config_for_stop_id("g") | routes: ["Green-B"]}

      sign = %{
        @sign
        | source_config: {[source_config]}
      }

      assert Signs.Utilities.Headways.get_messages(sign) ==
               {{source_config,
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_config, %Content.Message.Headways.Bottom{range: {nil, 7}}}}
    end

    test "generates blank messages to display when no headway information present" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("b")]}
      }

      assert Signs.Utilities.Headways.get_messages(sign) ==
               {{source_config_for_stop_id("b"), %Content.Message.Empty{}},
                {source_config_for_stop_id("b"), %Content.Message.Empty{}}}
    end

    test "generates blank messages for {nil, nil} headways" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("c")]}
      }

      assert Signs.Utilities.Headways.get_messages(sign) ==
               {{source_config_for_stop_id("c"), %Content.Message.Empty{}},
                {source_config_for_stop_id("c"), %Content.Message.Empty{}}}
    end

    test "generates blank messages to display more than one headway earlier than the first departure of the day" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("d")]}
      }

      assert Signs.Utilities.Headways.get_messages(sign) ==
               {{source_config_for_stop_id("d"), %Content.Message.Empty{}},
                {source_config_for_stop_id("d"), %Content.Message.Empty{}}}
    end

    test "generates a headway message to display immediately before the first departure of the day" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("e")]}
      }

      assert Signs.Utilities.Headways.get_messages(sign) ==
               {{source_config_for_stop_id("e"),
                 %Content.Message.Headways.Top{headsign: "Southbound", vehicle_type: :train}},
                {source_config_for_stop_id("e"), %Content.Message.Headways.Bottom{range: {1, 5}}}}
    end
  end
end
