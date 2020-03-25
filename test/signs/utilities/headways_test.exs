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
    def display_headways?(["no_service"], _time, _buffer), do: false
    def display_headways?(_, _time, _buffer), do: true
  end

  defmodule FakeHeadwayConfigEngine do
    def headway_config("first_dep_test", _time) do
      %Engine.Config.Headway{headway_id: "id", range_low: 7, range_high: 11}
    end

    def headway_config("config_test", _time) do
      %Engine.Config.Headway{headway_id: "id", range_low: 9, range_high: 13}
    end

    def headway_config("8-11", _time) do
      %Engine.Config.Headway{headway_id: "id", range_low: 8, range_high: 11}
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

  @current_time DateTime.utc_now()

  describe "get_messages/2" do
    test "generates blank messages when the source config has multiple sources and the sign has no headway_stop_id" do
      sign = %{@sign | source_config: {[], []}}

      assert Signs.Utilities.Headways.get_messages(sign, @current_time) ==
               {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}}
    end

    test "displays the headway at a single-source stop" do
      sign = %{
        @sign
        | source_config: {[source_config_for_stop_id("a")]},
          config_engine: FakeHeadwayConfigEngine,
          headway_group: "8-11"
      }

      assert Signs.Utilities.Headways.get_messages(sign, @current_time) ==
               {{source_config_for_stop_id("a"),
                 %Content.Message.Headways.Top{destination: :southbound, vehicle_type: :train}},
                {source_config_for_stop_id("a"),
                 %Content.Message.Headways.Bottom{
                   range: {8, 11},
                   prev_departure_mins: nil
                 }}}
    end

    test "displays the headway at multi-source stop that has a source_for_headway" do
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
          headway_group: "8-11"
      }

      assert Signs.Utilities.Headways.get_messages(sign, @current_time) ==
               {{source_with_headway,
                 %Content.Message.Headways.Top{destination: :southbound, vehicle_type: :train}},
                {source_with_headway,
                 %Content.Message.Headways.Bottom{
                   range: {8, 11},
                   prev_departure_mins: nil
                 }}}
    end

    test "generates empty messages if no headway is configured for some reason" do
      config = source_config_for_stop_id("a")

      sign = %{
        @sign
        | source_config: {[config]},
          config_engine: FakeHeadwayConfigEngine,
          headway_group: "none_configured"
      }

      assert Signs.Utilities.Headways.get_messages(sign, @current_time) ==
               {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}
    end

    test "generates empty messages if outside of service hours" do
      config = source_config_for_stop_id("no_service")

      sign = %{
        @sign
        | source_config: {[config]},
          config_engine: FakeHeadwayConfigEngine,
          headway_group: "8-11"
      }

      assert Signs.Utilities.Headways.get_messages(sign, @current_time) ==
               {{config, %Content.Message.Empty{}}, {config, %Content.Message.Empty{}}}
    end
  end
end
