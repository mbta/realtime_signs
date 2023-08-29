defmodule Signs.Utilities.EarlyAmSuppresionTest do
  use ExUnit.Case, async: true

  defmodule FakeHeadways do
    def display_headways?(_stop_ids, _time, _buffer), do: true
  end

  defmodule FakeNoHeadway do
    def display_headways?(_stop_ids, _time, _buffer), do: false
  end

  defmodule FakeConfigEngine do
    def headway_config("red_trunk", _time) do
      %Engine.Config.Headway{headway_id: "id", range_low: 8, range_high: 10}
    end
  end

  @src1 %Signs.Utilities.SourceConfig{
    stop_id: "1",
    direction_id: 0,
    platform: nil,
    terminal?: false,
    announce_arriving?: false,
    announce_boarding?: false,
    routes: ["Red"]
  }

  @src2 %Signs.Utilities.SourceConfig{
    stop_id: "2",
    direction_id: 1,
    platform: nil,
    terminal?: false,
    announce_arriving?: false,
    announce_boarding?: false
  }

  @platform_sign %Signs.Realtime{
    id: "platform_sign_id",
    text_id: {"TEST", "x"},
    audio_id: {"TEST", ["x"]},
    source_config: %{
      sources: [@src1],
      headway_destination: :southbound,
      headway_group: "red_trunk"
    },
    current_content_top: %Content.Message.Predictions{destination: :braintree, minutes: 3},
    current_content_bottom: %Content.Message.Predictions{destination: :ashmont, minutes: 4},
    prediction_engine: nil,
    headway_engine: FakeHeadways,
    config_engine: FakeConfigEngine,
    alerts_engine: nil,
    sign_updater: nil,
    tick_read: 1,
    read_period_seconds: 100,
    last_update: nil
  }

  @mezzanine_sign %Signs.Realtime{
    id: "mezzanine_sign_id",
    text_id: {"TEST", "x"},
    audio_id: {"TEST", ["x"]},
    source_config:
      {%{sources: [@src2], headway_group: "red_trunk", headway_destination: :southbound},
       %{sources: [@src1], headway_group: "red_trunk", headway_destination: :alewife}},
    current_content_top: nil,
    current_content_bottom: nil,
    prediction_engine: nil,
    headway_engine: FakeHeadways,
    config_engine: FakeConfigEngine,
    alerts_engine: nil,
    sign_updater: nil,
    tick_read: 1,
    read_period_seconds: 100,
    last_update: nil
  }
  @current_time ~U[2023-07-14 08:00:00Z]

  describe("do_early_am_suppression/5 platform cases") do
    @schedule {~U[2023-07-14 09:00:00Z], :southbound}
    test "When sign in full am suppression, show timestamp" do
      current_content =
        {%Content.Message.Predictions{destination: :braintree, minutes: 3},
         %Content.Message.Empty{}}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               :fully_suppressed,
               @schedule,
               @platform_sign
             ) ==
               {%Content.Message.EarlyAm.DestinationTrain{destination: :southbound},
                %Content.Message.EarlyAm.ScheduledTime{
                  scheduled_time: ~U[2023-07-14 09:00:00Z]
                }}
    end

    test "When sign in partial am suppression shows mid-trip and terminal predictions" do
      current_content =
        {%Content.Message.Predictions{destination: :braintree, minutes: 3, certainty: 60},
         %Content.Message.Predictions{destination: :braintree, minutes: 4, certainty: 120}}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               :partially_suppressed,
               @schedule,
               @platform_sign
             ) ==
               {%Content.Message.Predictions{destination: :braintree, minutes: 3, certainty: 60},
                %Content.Message.Predictions{destination: :braintree, minutes: 4, certainty: 120}}
    end

    test "When sign in partial am suppression, filters out reverse predictions" do
      current_content =
        {%Content.Message.Predictions{destination: :braintree, minutes: 3, certainty: 360},
         %Content.Message.Predictions{destination: :braintree, minutes: 4, certainty: 120}}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               :partially_suppressed,
               @schedule,
               @platform_sign
             ) ==
               {%Content.Message.Predictions{destination: :braintree, minutes: 4, certainty: 120},
                %Content.Message.Empty{}}
    end

    test "When sign in partial am suppression, no valid predictions, and within range of upper headway, show headways" do
      current_content =
        {%Content.Message.Predictions{destination: :braintree, minutes: 3, certainty: 360},
         %Content.Message.Empty{}}

      current_time = ~U[2023-07-14 08:51:00Z]

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               current_time,
               :partially_suppressed,
               @schedule,
               @platform_sign
             ) ==
               {%Content.Message.Headways.Top{destination: :southbound, vehicle_type: :train},
                %Content.Message.Headways.Bottom{prev_departure_mins: nil, range: {8, 10}}}
    end

    test "When sign in partial am suppression, no valid predictions, but not within range of upper headway, show timestamp" do
      current_content =
        {%Content.Message.Predictions{destination: :braintree, minutes: 3, certainty: 360},
         %Content.Message.Empty{}}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               :partially_suppressed,
               @schedule,
               %{@platform_sign | headway_engine: FakeNoHeadway}
             ) ==
               {%Content.Message.EarlyAm.DestinationTrain{destination: :southbound},
                %Content.Message.EarlyAm.ScheduledTime{scheduled_time: ~U[2023-07-14 09:00:00Z]}}
    end

    test "Stopped train messages get filtered based on certainty" do
      current_content =
        {%Content.Message.StoppedTrain{destination: :braintree, stops_away: 3, certainty: 360},
         %Content.Message.Empty{}}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               :partially_suppressed,
               @schedule,
               %{@platform_sign | headway_engine: FakeNoHeadway}
             ) ==
               {%Content.Message.EarlyAm.DestinationTrain{destination: :southbound},
                %Content.Message.EarlyAm.ScheduledTime{scheduled_time: ~U[2023-07-14 09:00:00Z]}}
    end
  end

  describe "do_early_am_suppression/5 mezzanine cases" do
    @schedule {{~U[2023-07-14 08:00:00Z], :alewife}, {~U[2023-07-14 09:00:00Z], :southbound}}
    test "Both lines in full am suppression" do
      current_content =
        {%Content.Message.Predictions{destination: :alewife, minutes: 3},
         %Content.Message.Predictions{destination: :braintree, minutes: 4}}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               {:fully_suppressed, :fully_suppressed},
               @schedule,
               @mezzanine_sign
             ) ==
               {
                 %Content.Message.GenericPaging{
                   messages: [
                     %Content.Message.EarlyAm.DestinationTrain{destination: :alewife},
                     %Content.Message.EarlyAm.DestinationTrain{destination: :southbound}
                   ]
                 },
                 %Content.Message.GenericPaging{
                   messages: [
                     %Content.Message.EarlyAm.ScheduledTime{
                       scheduled_time: ~U[2023-07-14 08:00:00Z]
                     },
                     %Content.Message.EarlyAm.ScheduledTime{
                       scheduled_time: ~U[2023-07-14 09:00:00Z]
                     }
                   ]
                 }
               }
    end

    test "One line in full am suppression, one line in partial am suppression defaulting to headways" do
      current_content =
        {%Content.Message.Predictions{destination: :alewife, minutes: 3},
         %Content.Message.Predictions{destination: :braintree, minutes: 4, certainty: 360}}

      northbound_headways_inactive = {~U[2023-07-14 09:00:00Z], :alewife}
      southbound_headways_active = {~U[2023-07-14 08:05:00Z], :southbound}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               {:fully_suppressed, :partially_suppressed},
               {northbound_headways_inactive, southbound_headways_active},
               @mezzanine_sign
             ) ==
               {
                 %Content.Message.GenericPaging{
                   messages: [
                     %Content.Message.EarlyAm.DestinationTrain{destination: :alewife},
                     %Content.Message.Headways.Top{
                       destination: :southbound,
                       vehicle_type: :train
                     }
                   ]
                 },
                 %Content.Message.GenericPaging{
                   messages: [
                     %Content.Message.EarlyAm.ScheduledTime{
                       scheduled_time: ~U[2023-07-14 09:00:00Z]
                     },
                     %Content.Message.Headways.Bottom{prev_departure_mins: nil, range: {8, 10}}
                   ]
                 }
               }
    end

    test "Both lines in partial am suppression defaulting to headways" do
      current_content =
        {%Content.Message.Predictions{destination: :alewife, minutes: 3, certainty: 360},
         %Content.Message.Predictions{destination: :braintree, minutes: 4, certainty: 360}}

      southbound_headways_active = {~U[2023-07-14 08:05:00Z], :southbound}
      northbound_headways_active = {~U[2023-07-14 08:05:00Z], :alewife}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               {:partially_suppressed, :partially_suppressed},
               {northbound_headways_active, southbound_headways_active},
               @mezzanine_sign
             ) ==
               {%Content.Message.Headways.Top{
                  destination: :alewife,
                  vehicle_type: :train,
                  routes: ["Red"]
                }, %Content.Message.Headways.Bottom{prev_departure_mins: nil, range: {8, 10}}}
    end

    test "One line showing prediction, one line default to paging headway" do
      current_content =
        {%Content.Message.Predictions{destination: :alewife, minutes: 3, certainty: 360},
         %Content.Message.Predictions{destination: :braintree, minutes: 4, certainty: 60}}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               {:partially_suppressed, :partially_suppressed},
               @schedule,
               @mezzanine_sign
             ) ==
               {%Content.Message.Predictions{
                  destination: :braintree,
                  certainty: 60,
                  minutes: 4
                }, %Content.Message.Headways.Paging{range: {8, 10}, destination: :alewife}}
    end

    test "One line showing prediction, one line showing timestamp" do
      current_content =
        {%Content.Message.Predictions{destination: :alewife, minutes: 3, certainty: 360},
         %Content.Message.Predictions{destination: :braintree, minutes: 4, certainty: 60}}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               {:partially_suppressed, :partially_suppressed},
               @schedule,
               %{@mezzanine_sign | headway_engine: FakeNoHeadway}
             ) ==
               {%Content.Message.Predictions{
                  destination: :braintree,
                  certainty: 60,
                  minutes: 4
                },
                %Content.Message.EarlyAm.DestinationScheduledTime{
                  destination: :alewife,
                  scheduled_time: ~U[2023-07-14 08:00:00Z]
                }}
    end

    test "Both lines showing prediction" do
      current_content =
        {%Content.Message.Predictions{destination: :alewife, minutes: 3, certainty: 60},
         %Content.Message.Predictions{destination: :braintree, minutes: 4, certainty: 60}}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               {:partially_suppressed, :partially_suppressed},
               @schedule,
               @mezzanine_sign
             ) ==
               {%Content.Message.Predictions{
                  destination: :alewife,
                  certainty: 60,
                  minutes: 3
                },
                %Content.Message.Predictions{
                  destination: :braintree,
                  certainty: 60,
                  minutes: 4
                }}
    end
  end

  describe "do_early_am_suppression/5 JFK/UMass mezzanine special cases" do
    @schedule {{~U[2023-07-14 09:00:00Z], :southbound}, {~U[2023-07-14 09:00:00Z], :alewife}}

    test "Southbound on timestamp and Alewife on platform prediction" do
      current_content =
        {%Content.Message.Predictions{destination: :braintree, minutes: 3, certainty: 360},
         %Content.Message.Predictions{
           destination: :alewife,
           minutes: 4,
           certainty: 60,
           station_code: "RJFK",
           zone: "m"
         }}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               {:partially_suppressed, :partially_suppressed},
               @schedule,
               %{@mezzanine_sign | headway_engine: FakeNoHeadway}
             ) ==
               {
                 %Content.Message.GenericPaging{
                   messages: [
                     %Content.Message.EarlyAm.DestinationTrain{destination: :southbound},
                     %Content.Message.Predictions{
                       certainty: 60,
                       destination: :alewife,
                       minutes: 4,
                       station_code: "RJFK",
                       zone: nil
                     }
                   ]
                 },
                 %Content.Message.GenericPaging{
                   messages: [
                     %Content.Message.EarlyAm.ScheduledTime{
                       scheduled_time: ~U[2023-07-14 09:00:00Z]
                     },
                     %Content.Message.PlatformPredictionBottom{minutes: 4, stop_id: nil}
                   ]
                 }
               }
    end

    test "Southbound on headways and Alewife on platform prediction" do
      current_content =
        {%Content.Message.Predictions{destination: :braintree, minutes: 3, certainty: 360},
         %Content.Message.Predictions{
           destination: :alewife,
           minutes: 4,
           certainty: 60,
           station_code: "RJFK",
           zone: "m"
         }}

      southbound_headways_active = {~U[2023-07-14 08:05:00Z], :southbound}
      northbound_headways_active = {~U[2023-07-14 08:05:00Z], :alewife}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               {:partially_suppressed, :partially_suppressed},
               {southbound_headways_active, northbound_headways_active},
               @mezzanine_sign
             ) ==
               {
                 %Content.Message.GenericPaging{
                   messages: [
                     %Content.Message.Headways.Top{
                       destination: :southbound,
                       vehicle_type: :train
                     },
                     %Content.Message.Predictions{
                       certainty: 60,
                       destination: :alewife,
                       minutes: 4,
                       station_code: "RJFK",
                       zone: nil
                     }
                   ]
                 },
                 %Content.Message.GenericPaging{
                   messages: [
                     %Content.Message.Headways.Bottom{prev_departure_mins: nil, range: {8, 10}},
                     %Content.Message.PlatformPredictionBottom{minutes: 4, stop_id: nil}
                   ]
                 }
               }
    end

    test "Filtered platform prediction and headways returns full page headways" do
      current_content =
        {%Content.Message.GenericPaging{
           messages: [
             %Content.Message.Predictions{
               destination: :alewife,
               minutes: 3,
               certainty: 360,
               station_code: "RJFK",
               zone: "m"
             },
             %Content.Message.Headways.Top{destination: :southbound, vehicle_type: :train}
           ]
         },
         %Content.Message.GenericPaging{
           messages: [
             %Content.Message.PlatformPredictionBottom{minutes: 3, stop_id: nil},
             %Content.Message.Headways.Bottom{range: {8, 10}}
           ]
         }}

      southbound_headways_active = {~U[2023-07-14 08:05:00Z], :southbound}
      northbound_headways_active = {~U[2023-07-14 08:05:00Z], :alewife}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               {:partially_suppressed, :partially_suppressed},
               {southbound_headways_active, northbound_headways_active},
               @mezzanine_sign
             ) ==
               {%Content.Message.Headways.Top{
                  destination: :southbound,
                  routes: ["Red"],
                  vehicle_type: :train
                }, %Content.Message.Headways.Bottom{prev_departure_mins: nil, range: {8, 10}}}
    end

    test "Valid platform prediction and non suppressed headway gets passed through" do
      current_content =
        {%Content.Message.GenericPaging{
           messages: [
             %Content.Message.Predictions{
               destination: :alewife,
               minutes: 3,
               certainty: 60,
               station_code: "RJFK",
               zone: "m"
             },
             %Content.Message.Headways.Top{destination: :southbound, vehicle_type: :train}
           ]
         },
         %Content.Message.GenericPaging{
           messages: [
             %Content.Message.PlatformPredictionBottom{minutes: 3, stop_id: nil},
             %Content.Message.Headways.Bottom{range: {8, 10}}
           ]
         }}

      assert Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
               current_content,
               @current_time,
               {:none, :partially_suppressed},
               @schedule,
               @mezzanine_sign
             ) ==
               {
                 %Content.Message.GenericPaging{
                   messages: [
                     %Content.Message.Headways.Top{
                       destination: :southbound,
                       routes: nil,
                       vehicle_type: :train
                     },
                     %Content.Message.Predictions{
                       certainty: 60,
                       destination: :alewife,
                       minutes: 3,
                       station_code: "RJFK",
                       width: 18,
                       zone: nil
                     }
                   ]
                 },
                 %Content.Message.GenericPaging{
                   messages: [
                     %Content.Message.Headways.Bottom{prev_departure_mins: nil, range: {8, 10}},
                     %Content.Message.PlatformPredictionBottom{
                       destination: nil,
                       minutes: 3,
                       stop_id: nil
                     }
                   ]
                 }
               }
    end
  end
end
