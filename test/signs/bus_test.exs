defmodule Signs.BusTest do
  use ExUnit.Case, async: true
  import Mox

  defmodule FakeBusPredictions do
    def predictions_for_stop("stop1") do
      [
        %Predictions.BusPrediction{
          direction_id: 0,
          departure_time: Timex.shift(Timex.now(), minutes: 2),
          route_id: "14",
          stop_id: "stop1",
          headsign: "Wakefield Ave",
          vehicle_id: "a",
          trip_id: "a",
          updated_at: ""
        },
        %Predictions.BusPrediction{
          direction_id: 0,
          departure_time: Timex.shift(Timex.now(), minutes: 11),
          route_id: "14",
          stop_id: "stop1",
          headsign: "Wakefield Ave",
          vehicle_id: "b",
          trip_id: "b",
          updated_at: ""
        },
        %Predictions.BusPrediction{
          direction_id: 1,
          departure_time: Timex.shift(Timex.now(), minutes: 7),
          route_id: "34",
          stop_id: "stop1",
          headsign: "Clarendon Hill",
          vehicle_id: "c",
          trip_id: "c",
          updated_at: ""
        },
        %Predictions.BusPrediction{
          direction_id: 1,
          departure_time: Timex.shift(Timex.now(), minutes: 4),
          route_id: "741",
          stop_id: "stop1",
          headsign: "Chelsea",
          vehicle_id: "d",
          trip_id: "d",
          updated_at: ""
        }
      ]
    end

    def predictions_for_stop("stop2") do
      [
        %Predictions.BusPrediction{
          direction_id: 0,
          departure_time: Timex.shift(Timex.now(), minutes: 8),
          route_id: "749",
          stop_id: "stop2",
          headsign: "Nubian",
          vehicle_id: "e",
          trip_id: "e",
          updated_at: ""
        }
      ]
    end

    def predictions_for_stop("stop3") do
      []
    end
  end

  defmodule FakeConfig do
    def sign_config("auto_sign", _default), do: :auto
    def sign_config("off_sign", _default), do: :off
    def sign_config("headway", _default), do: :headway
    def sign_config("static_sign", _default), do: {:static_text, {"custom", "message"}}
    def chelsea_bridge_config(), do: :auto
  end

  defmodule FakeChelseaBridge do
    def bridge_status(), do: %{raised?: false, estimate: nil}
  end

  defmodule FakeChelseaBridgeRaised do
    def bridge_status(), do: %{raised?: true, estimate: Timex.shift(Timex.now(), minutes: 4)}
  end

  defmodule FakeAlerts do
    def stop_status("stop3"), do: :station_closure
    def stop_status(_), do: :none
    def route_status("51"), do: :suspension_closed_station
    def route_status(_), do: :none
  end

  defmodule FakeRoutes do
    def route_destination("51", 0), do: "Reservoir Station"
  end

  @sign_state %Signs.Bus{
    id: "auto_sign",
    pa_ess_loc: "ABCD",
    scu_id: "ABCDSCU001",
    text_zone: "m",
    audio_zones: ["m"],
    max_minutes: 60,
    configs: nil,
    top_configs: nil,
    bottom_configs: nil,
    extra_audio_configs: nil,
    chelsea_bridge: nil,
    read_loop_interval: 360,
    read_loop_offset: 30,
    config_engine: FakeConfig,
    prediction_engine: FakeBusPredictions,
    bridge_engine: FakeChelseaBridge,
    alerts_engine: FakeAlerts,
    routes_engine: FakeRoutes,
    sign_updater: PaEss.Updater.Mock,
    prev_predictions: [],
    prev_bridge_status: nil,
    current_messages: {nil, nil},
    last_update: nil,
    last_read_time: Timex.shift(Timex.now(), minutes: -10),
    pa_message_plays: %{}
  }

  setup :verify_on_exit!

  describe "run loop" do
    test "platform mode, top two" do
      expect_messages(["14 WakfldAv  2 min", "14 WakfldAv 11 min"])

      expect_audios(
        [
          {:canned,
           {"119",
            [
              "501",
              "575",
              "859",
              "621",
              "503",
              "504",
              "5502",
              "505",
              "21012",
              "667",
              "575",
              "859",
              "621",
              "503",
              "504",
              "5511",
              "505"
            ], :audio}}
        ],
        [
          {"The next route 14 bus to Wakefield Ave arrives in 2 minutes. The following route 14 bus to Wakefield Ave arrives in 11 minutes.",
           nil}
        ]
      )

      state =
        Map.merge(@sign_state, %{
          configs: [%{sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}]}]
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "platform mode, multiple pages" do
      expect_messages([
        [{"14 WakefldAv 2 min", 6}, {"34 Clarendon 7 min", 6}],
        [{"Chelsea      4 min", 6}, {"", 6}]
      ])

      expect_audios(
        [
          {:canned,
           {"117",
            [
              "548",
              "21012",
              "575",
              "621",
              "5502",
              "505",
              "21012",
              "860",
              "5504",
              "505",
              "21012",
              "678",
              "605",
              "5507",
              "505"
            ], :audio}}
        ],
        [
          {"Upcoming departures: Route 14, Wakefield Ave, 2 minutes. Chelsea, 4 minutes. Route 34, Clarendon Hill, 7 minutes.",
           nil}
        ]
      )

      state =
        Map.merge(@sign_state, %{
          configs: [
            %{sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}]},
            %{sources: [%{stop_id: "stop1", route_id: "34", direction_id: 1}]},
            %{sources: [%{stop_id: "stop1", route_id: "741", direction_id: 1}]}
          ]
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "mezzanine mode" do
      expect_messages(["SL5 Nubian   8 min", "14 WakefldAv 2 min"])

      expect_audios(
        [
          {:canned,
           {"113",
            ["548", "21012", "587", "812", "5508", "505", "21012", "575", "621", "5502", "505"],
            :audio}}
        ],
        [
          {"Upcoming departures: Route SL5, Nubian, 8 minutes. Route 14, Wakefield Ave, 2 minutes.",
           nil}
        ]
      )

      state =
        Map.merge(@sign_state, %{
          top_configs: [%{sources: [%{stop_id: "stop2", route_id: "749", direction_id: 0}]}],
          bottom_configs: [%{sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}]}]
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "static mode" do
      expect_messages(["custom", "message"])
      expect_audios([{:ad_hoc, {"custom message", :audio}}], [{"custom message", nil}])

      state = Map.merge(@sign_state, %{id: "static_sign"})

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "off mode" do
      expect_messages(["", ""])

      state =
        Map.merge(@sign_state, %{
          id: "off_sign",
          configs: [%{sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}]}]
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "SL headway mode" do
      expect_messages(["", ""])

      state =
        Map.merge(@sign_state, %{
          id: "headway",
          configs: [%{sources: [%{stop_id: "stop1", route_id: "741", direction_id: 0}]}]
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "bridge raised" do
      expect_messages([
        [{"14 WakfldAv  2 min", 6}, {"Drawbridge is up", 6}],
        [{"14 WakfldAv 11 min", 6}, {"SL3 delays 4 more min", 6}]
      ])

      expect_audios(
        [
          {:canned,
           {"119",
            [
              "501",
              "575",
              "859",
              "621",
              "503",
              "504",
              "5502",
              "505",
              "21012",
              "667",
              "575",
              "859",
              "621",
              "503",
              "504",
              "5511",
              "505"
            ], :audio}},
          {:canned, {"135", ["5504"], :audio_visual}},
          {:canned, {"152", ["37004"], :audio_visual}}
        ],
        [
          {"The next route 14 bus to Wakefield Ave arrives in 2 minutes. The following route 14 bus to Wakefield Ave arrives in 11 minutes.",
           nil},
          {"The Chelsea Street bridge is raised. We expect this to last for at least 4 more minutes. SL3 buses may be delayed, detoured, or turned back.",
           [
             {"The Chelsea Street", "bridge is raised. We", 3},
             {"expect this to last for", "at least 4 more minutes.", 3},
             {"SL3 buses may be", "delayed, detoured, or", 3},
             {"turned back.", "", 3}
           ]},
          {"El puente de Chelsea Street está levantado. Esperamos que esto dure al menos 4 minutos más. Los autobuses SL3 pueden sufrir retrasos, desvíos o dar marcha atrás.",
           [
             {"El puente de Chelsea", "Street está levantado.", 3},
             {"Esperamos que esto dure", "al menos 4 minutos más.", 3},
             {"Los autobuses SL3 pueden", "sufrir retrasos, desvíos", 3},
             {"o dar marcha atrás.", "", 3}
           ]}
        ]
      )

      state =
        Map.merge(@sign_state, %{
          configs: [%{sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}]}],
          chelsea_bridge: "audio_visual",
          bridge_engine: FakeChelseaBridgeRaised
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "standalone bridge announcement" do
      expect_audios(
        [
          {:canned, {"135", ["5504"], :audio_visual}},
          {:canned, {"152", ["37004"], :audio_visual}}
        ],
        [
          {"The Chelsea Street bridge is raised. We expect this to last for at least 4 more minutes. SL3 buses may be delayed, detoured, or turned back.",
           [
             {"The Chelsea Street", "bridge is raised. We", 3},
             {"expect this to last for", "at least 4 more minutes.", 3},
             {"SL3 buses may be", "delayed, detoured, or", 3},
             {"turned back.", "", 3}
           ]},
          {"El puente de Chelsea Street está levantado. Esperamos que esto dure al menos 4 minutos más. Los autobuses SL3 pueden sufrir retrasos, desvíos o dar marcha atrás.",
           [
             {"El puente de Chelsea", "Street está levantado.", 3},
             {"Esperamos que esto dure", "al menos 4 minutos más.", 3},
             {"Los autobuses SL3 pueden", "sufrir retrasos, desvíos", 3},
             {"o dar marcha atrás.", "", 3}
           ]}
        ]
      )

      state =
        Map.merge(@sign_state, %{
          configs: [%{sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}]}],
          chelsea_bridge: "audio",
          bridge_engine: FakeChelseaBridgeRaised,
          prev_bridge_status: %{raised?: false, estimate: nil},
          current_messages: {"14 WakfldAv  2 min", "14 WakfldAv 11 min"},
          last_update: Timex.shift(Timex.now(), seconds: -40),
          last_read_time: Timex.now()
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "no service alert" do
      expect_messages(["No bus service", ""])
      expect_audios([{:canned, {"103", ["878"], :audio}}], [{"No bus service", nil}])

      state =
        Map.merge(@sign_state, %{
          configs: [%{sources: [%{stop_id: "stop3", route_id: "99", direction_id: 0}]}]
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "route alert on multi-route sign" do
      expect_messages(["14 WakefldAv 2 min", "51 Resrvoir no svc"])

      expect_audios(
        [
          {:canned,
           {"112", ["548", "21012", "575", "621", "5502", "505", "21012", "687", "4076", "879"],
            :audio}}
        ],
        [
          {"Upcoming departures: Route 14, Wakefield Ave, 2 minutes. Route 51, Reservoir Station, no service.",
           nil}
        ]
      )

      state = %{
        @sign_state
        | configs: [
            %{sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}]},
            %{sources: [%{stop_id: "stop1", route_id: "51", direction_id: 0}]}
          ]
      }

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "route alert on single-route sign" do
      expect_messages(["51 Resrvoir no svc", ""])

      expect_audios([{:canned, {"106", ["880", "687", "877", "4076"], :audio}}], [
        {"There is no route 51 bus service to Reservoir Station.", nil}
      ])

      state = %{
        @sign_state
        | configs: [%{sources: [%{stop_id: "stop1", route_id: "51", direction_id: 0}]}]
      }

      Signs.Bus.handle_info(:run_loop, state)
    end
  end

  defp expect_messages(messages) do
    expect(PaEss.Updater.Mock, :set_background_message, fn _, top, bottom ->
      assert [top, bottom] == messages
      :ok
    end)
  end

  defp expect_audios(audios, tts_audios) do
    expect(PaEss.Updater.Mock, :play_message, fn _, list, tts_list, _ ->
      assert list == audios
      assert tts_list == tts_audios
      :ok
    end)
  end
end
