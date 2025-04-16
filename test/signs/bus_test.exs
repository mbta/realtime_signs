defmodule Signs.BusTest do
  use ExUnit.Case, async: true
  import Mox

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
    prev_predictions: [],
    prev_bridge_status: nil,
    current_messages: {nil, nil},
    last_update: nil,
    last_read_time: Timex.shift(Timex.now(), minutes: -10),
    pa_message_plays: %{}
  }

  setup :verify_on_exit!

  describe "run loop" do
    setup do
      stub(Engine.BusPredictions.Mock, :predictions_for_stop, fn
        "stop1" ->
          [
            prediction(
              departure: 2,
              stop_id: "stop1",
              direction_id: 0,
              route_id: "14",
              headsign: "Wakefield Ave"
            ),
            prediction(
              departure: 11,
              stop_id: "stop1",
              direction_id: 0,
              route_id: "14",
              headsign: "Wakefield Ave"
            ),
            prediction(
              departure: 7,
              stop_id: "stop1",
              direction_id: 1,
              route_id: "34",
              headsign: "Clarendon Hill"
            ),
            prediction(
              departure: 4,
              stop_id: "stop1",
              direction_id: 1,
              route_id: "741",
              headsign: "Chelsea"
            )
          ]

        "stop2" ->
          [
            prediction(
              departure: 8,
              stop_id: "stop2",
              direction_id: 0,
              route_id: "749",
              headsign: "Nubian"
            )
          ]

        "stop3" ->
          []
      end)

      stub(Engine.BusPredictions.Mock, :get_child_stops_if_parent, fn stop_id -> [stop_id] end)

      stub(Engine.Config.Mock, :sign_config, fn
        "auto_sign", _default -> :auto
        "off_sign", _default -> :off
        "headway", _default -> :headway
        "static_sign", _default -> {:static_text, {"custom", "message"}}
      end)

      stub(Engine.Config.Mock, :chelsea_bridge_config, fn -> :auto end)

      stub(Engine.Alerts.Mock, :stop_status, fn
        "stop3" -> :station_closure
        _ -> :none
      end)

      stub(Engine.Alerts.Mock, :route_status, fn
        "51" -> :suspension_closed_station
        _ -> :none
      end)

      stub(Engine.ChelseaBridge.Mock, :bridge_status, fn -> %{raised?: false, estimate: nil} end)
      stub(Engine.Routes.Mock, :route_destination, fn "51", 0 -> "Reservoir Station" end)

      :ok
    end

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
          configs: [
            %{
              sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}],
              consolidate?: false
            }
          ]
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
            %{
              sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}],
              consolidate?: false
            },
            %{
              sources: [%{stop_id: "stop1", route_id: "34", direction_id: 1}],
              consolidate?: false
            },
            %{
              sources: [%{stop_id: "stop1", route_id: "741", direction_id: 1}],
              consolidate?: false
            }
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
          top_configs: [
            %{
              sources: [%{stop_id: "stop2", route_id: "749", direction_id: 0}],
              consolidate?: false
            }
          ],
          bottom_configs: [
            %{
              sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}],
              consolidate?: false
            }
          ]
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
      expect(Engine.ChelseaBridge.Mock, :bridge_status, fn ->
        %{raised?: true, estimate: Timex.shift(Timex.now(), minutes: 4)}
      end)

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
          {
            {:spanish,
             "El puente levadizo de Chelsea está abierto. Permanecerá abierto aproximadamente 4 minutos. Autobuses S.L. tres pueden experimentar retrasos, ser desviados o devueltos."},
            [
              {"El puente levadizo de", "Chelsea está abierto.", 3},
              {"Permanecerá abierto", "aproximadamente 4", 3},
              {"minutos. Autobuses S.L.", "tres pueden experimentar", 3},
              {"retrasos, ser desviados", "o devueltos.", 3}
            ]
          }
        ]
      )

      state =
        Map.merge(@sign_state, %{
          configs: [
            %{
              sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}],
              consolidate?: false
            }
          ],
          chelsea_bridge: "audio_visual"
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "standalone bridge announcement" do
      expect(Engine.ChelseaBridge.Mock, :bridge_status, fn ->
        %{raised?: true, estimate: Timex.shift(Timex.now(), minutes: 4)}
      end)

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
          {
            {:spanish,
             "El puente levadizo de Chelsea está abierto. Permanecerá abierto aproximadamente 4 minutos. Autobuses S.L. tres pueden experimentar retrasos, ser desviados o devueltos."},
            [
              {"El puente levadizo de", "Chelsea está abierto.", 3},
              {"Permanecerá abierto", "aproximadamente 4", 3},
              {"minutos. Autobuses S.L.", "tres pueden experimentar", 3},
              {"retrasos, ser desviados", "o devueltos.", 3}
            ]
          }
        ]
      )

      state =
        Map.merge(@sign_state, %{
          configs: [
            %{
              sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}],
              consolidate?: false
            }
          ],
          chelsea_bridge: "audio",
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
          configs: [
            %{
              sources: [%{stop_id: "stop3", route_id: "99", direction_id: 0}],
              consolidate?: false
            }
          ]
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
            %{
              sources: [%{stop_id: "stop1", route_id: "14", direction_id: 0}],
              consolidate?: false
            },
            %{
              sources: [%{stop_id: "stop1", route_id: "51", direction_id: 0}],
              consolidate?: false
            }
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
        | configs: [
            %{
              sources: [%{stop_id: "stop1", route_id: "51", direction_id: 0}],
              consolidate?: false
            }
          ]
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
    expect(PaEss.Updater.Mock, :play_message, fn _, list, tts_list, _, _ ->
      assert list == audios
      assert tts_list == tts_audios
      :ok
    end)
  end

  defp prediction(opts) do
    %Predictions.BusPrediction{
      direction_id: opts[:direction_id],
      departure_time: Timex.shift(Timex.now(), minutes: opts[:departure]),
      route_id: opts[:route_id],
      stop_id: opts[:stop_id],
      headsign: opts[:headsign],
      vehicle_id: "a",
      trip_id: "a",
      updated_at: ""
    }
  end
end
