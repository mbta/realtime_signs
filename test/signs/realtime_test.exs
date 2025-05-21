defmodule Signs.RealtimeTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  import Mox

  @headway_config %Engine.Config.Headway{headway_id: "id", range_low: 11, range_high: 13}

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    direction_id: 0,
    routes: ["Red"],
    announce_arriving?: true,
    announce_boarding?: false
  }

  @src_2 %Signs.Utilities.SourceConfig{
    stop_id: "2",
    direction_id: 0,
    routes: ["Red"],
    announce_arriving?: true,
    announce_boarding?: false
  }

  @fake_time DateTime.new!(~D[2023-01-01], ~T[12:00:00], "America/New_York")
  def fake_time_fn, do: @fake_time

  @midnight_time DateTime.new!(~D[2023-01-01], ~T[00:00:00], "America/New_York")
  def fake_midnight_fn, do: @midnight_time

  @sign %Signs.Realtime{
    id: "sign_id",
    pa_ess_loc: "TEST",
    scu_id: "TESTSCU001",
    text_zone: "x",
    audio_zones: ["x"],
    source_config: %{
      terminal?: false,
      sources: [@src],
      headway_group: "headway_group",
      headway_destination: :southbound
    },
    current_content_top: "Southbound trains",
    current_content_bottom: "Every 11 to 13 min",
    current_time_fn: &Signs.RealtimeTest.fake_time_fn/0,
    last_update: @fake_time,
    tick_read: 1,
    read_period_seconds: 100,
    pa_message_plays: %{}
  }

  @mezzanine_sign %{
    @sign
    | source_config: {
        %{
          sources: [@src],
          headway_group: "group",
          headway_destination: :northbound,
          terminal?: false
        },
        %{
          sources: [@src_2],
          headway_group: "group",
          headway_destination: :southbound,
          terminal?: false
        }
      },
      current_content_top: "Red line trains",
      current_content_bottom: "Every 11 to 13 min"
  }

  @multi_route_mezzanine_sign %{
    @sign
    | source_config: {
        %{
          sources: [%{@src | routes: ["Orange"]}],
          headway_group: "group",
          headway_destination: :northbound,
          terminal?: false
        },
        %{
          sources: [@src_2],
          headway_group: "group",
          headway_destination: :southbound,
          terminal?: false
        }
      },
      current_content_top: "Trains",
      current_content_bottom: "Every 11 to 13 min"
  }

  @jfk_mezzanine_sign %{
    @sign
    | pa_ess_loc: "RJFK",
      text_zone: "m",
      source_config: {
        %{
          sources: [@src],
          headway_group: "group",
          headway_destination: :southbound,
          terminal?: false
        },
        %{
          sources: [%{@src | stop_id: "70086", direction_id: 1}],
          headway_group: "group",
          headway_destination: :alewife,
          terminal?: false
        }
      }
  }

  @terminal_sign %{
    @sign
    | source_config: %{
        @sign.source_config
        | terminal?: true,
          sources: [
            %{@src | announce_arriving?: false, announce_boarding?: true}
          ]
      }
  }

  @alewife_sign %{
    @terminal_sign
    | source_config: %{
        @sign.source_config
        | terminal?: true,
          sources: [
            %{@src | announce_arriving?: false, announce_boarding?: true, stop_id: "70061"}
          ]
      }
  }

  @ashmont_sign %{
    @sign
    | source_config: %{
        headway_group: "group",
        headway_destination: :alewife,
        terminal?: true,
        sources: [
          %{
            stop_id: "70094",
            direction_id: 1,
            announce_arriving?: false,
            announce_boarding?: true,
            routes: ["Red"]
          }
        ]
      }
  }

  setup :verify_on_exit!

  describe "run loop" do
    setup do
      stub(Engine.Config.Mock, :sign_config, fn _, _ -> :auto end)
      stub(Engine.Config.Mock, :headway_config, fn _, _ -> @headway_config end)
      stub(Engine.Alerts.Mock, :min_stop_status, fn _ -> :none end)
      stub(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)
      stub(Engine.ScheduledHeadways.Mock, :display_headways?, fn _, _, _ -> true end)
      stub(Engine.Locations.Mock, :for_vehicle, fn _ -> nil end)
      stub(Engine.LastTrip.Mock, :is_last_trip?, fn _ -> false end)
      stub(Engine.LastTrip.Mock, :get_recent_departures, fn _ -> %{} end)

      stub(Engine.ScheduledHeadways.Mock, :get_first_scheduled_departure, fn _ ->
        datetime(~T[05:00:00])
      end)

      stub(Engine.ScheduledHeadways.Mock, :get_last_scheduled_departure, fn _ ->
        datetime(~D[2023-01-02], ~T[02:00:00])
      end)

      :ok
    end

    test "starts up and logs unknown messages" do
      assert {:ok, pid} = GenServer.start_link(Signs.Realtime, @sign)

      log =
        capture_log([level: :warning], fn ->
          send(pid, :foo)
          Process.sleep(50)
        end)

      assert Process.alive?(pid)
      assert log =~ "unknown_message"
    end

    test "decrements ticks and doesn't send audio or text when sign is not expired" do
      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, @sign)
      assert sign.tick_read == 0
    end

    test "refreshes content when expired" do
      expect_messages({"Southbound trains", "Every 11 to 13 min"})
      sign = %{@sign | last_update: Timex.shift(@fake_time, seconds: -200)}
      Signs.Realtime.handle_info(:run_loop, sign)
    end

    test "announces train passing through station" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :riverside, seconds_until_passthrough: 30, trip_id: "123"),
          prediction(destination: :riverside, seconds_until_passthrough: 30, trip_id: "124")
        ]
      end)

      expect_audios(
        [
          {:canned,
           {"114", spaced(["501", "905", "919", "918", "929", "21014", "925"]), :audio_visual}}
        ],
        [
          {"The next D train to Riverside does not take customers. Please stand back from the platform edge.",
           [
             {"The next D train to", "Riverside does not take", 3},
             {"customers. Please stand", "back from the platform", 3},
             {"edge.", "", 3}
           ]}
        ]
      )

      assert {:noreply, sign} = Signs.Realtime.handle_info(:run_loop, @sign)
      assert sign.announced_passthroughs == ["123"]
    end

    test "announces passthrough trains for mezzanine signs" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :braintree, seconds_until_passthrough: 30, trip_id: "123")]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, seconds_until_passthrough: 30, trip_id: "124")]
      end)

      expect_audios(
        [
          {:canned, {"112", spaced(["501", "787", "920", "929", "21014", "925"]), :audio_visual}}
        ],
        [
          {"The next Southbound train does not take customers. Please stand back from the platform edge.",
           [
             {"The next Southbound", "train does not take", 3},
             {"customers. Please stand", "back from the platform", 3},
             {"edge.", "", 3}
           ]}
        ]
      )

      expect_audios(
        [
          {:canned, {"112", spaced(["501", "892", "920", "929", "21014", "925"]), :audio_visual}}
        ],
        [
          {"The next Alewife train does not take customers. Please stand back from the platform edge.",
           [
             {"The next Alewife train", "does not take customers.", 3},
             {"Please stand back from", "the platform edge.", 3}
           ]}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, @mezzanine_sign)
    end

    test "announces passthrough audio for 'Southbound' headsign" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :southbound, seconds_until_passthrough: 30)]
      end)

      expect_audios(
        [
          {:canned, {"112", spaced(["501", "787", "920", "929", "21014", "925"]), :audio_visual}}
        ],
        [
          {"The next Southbound train does not take customers. Please stand back from the platform edge.",
           [
             {"The next Southbound", "train does not take", 3},
             {"customers. Please stand", "back from the platform", 3},
             {"edge.", "", 3}
           ]}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when custom text is present, display it, overriding alerts" do
      expect(Engine.Config.Mock, :sign_config, fn _, _ ->
        {:static_text, {"custom", "message"}}
      end)

      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :suspension_closed_station end)
      expect_messages({"custom", "message"})
      expect_audios([{:ad_hoc, {"custom message", :audio}}], [{"custom message", nil}])

      assert {_, %{announced_custom_text: "custom message"}} =
               Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is disabled, it's empty" do
      expect(Engine.Config.Mock, :sign_config, fn _, _ -> :off end)
      expect_messages({"", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign has a default mode, uses that when the sign has no mode configured" do
      expect(Engine.Config.Mock, :sign_config, fn _, default -> default end)
      sign = %{@sign | default_mode: {:static_text, {"default", "message"}}}

      expect_messages({"default", "message"})
      expect_audios([{:ad_hoc, {"default message", :audio}}], [{"default message", nil}])
      Signs.Realtime.handle_info(:run_loop, sign)
    end

    test "when sign is at a transfer station from a shuttle, and there are no predictions it's empty" do
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :shuttles_transfer_station end)
      expect_messages({"", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a transfer station from a suspension, and there are no predictions it's empty" do
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :suspension_transfer_station end)
      expect_messages({"", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a station closed by shuttles and there are no predictions, it says so" do
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :shuttles_closed_station end)
      expect_messages({"No Southbound svc", "Use shuttle bus"})

      expect_audios([{:ad_hoc, {"No Southbound service. Use shuttle.", :audio}}], [
        {"No Southbound service. Use shuttle.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a station closed and there are no predictions, but shuttles do not run at this station" do
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :shuttles_closed_station end)
      expect_messages({"No Southbound svc", ""})

      expect_audios([{:ad_hoc, {"No Southbound service.", :audio}}], [
        {"No Southbound service.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, %{@sign | uses_shuttles: false})
    end

    test "when sign is at a station closed due to suspension and there are no predictions, it says so" do
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :suspension_closed_station end)
      expect_messages({"No Southbound svc", ""})

      expect_audios([{:ad_hoc, {"No Southbound service.", :audio}}], [
        {"No Southbound service.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a closed station and there are no predictions, it says so" do
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :station_closure end)
      expect_messages({"No Southbound svc", ""})

      expect_audios([{:ad_hoc, {"No Southbound service.", :audio}}], [
        {"No Southbound service.", nil}
      ])

      assert {_, %{announced_alert: true}} = Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "mezzanine sign with alert" do
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :station_closure end)
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :station_closure end)
      expect_messages({"No Red Line", ""})

      expect_audios([{:canned, {"107", spaced(["861", "3005", "863"]), :audio}}], [
        {"There is no Red Line service at this station.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, @mezzanine_sign)
    end

    test "multi-route mezzanine sign with alert" do
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :station_closure end)
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :station_closure end)
      expect_messages({"No train service", ""})

      expect_audios([{:canned, {"107", spaced(["861", "864", "863"]), :audio}}], [
        {"There is no train service at this station.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, @multi_route_mezzanine_sign)
    end

    test "predictions take precedence over alerts" do
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :suspension_closed_station end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 120)]
      end)

      expect_messages({"Ashmont      2 min", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when there are predictions, puts predictions on the sign" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 120),
          prediction(destination: :ashmont, arrival: 240),
          prediction(destination: :ashmont, arrival: 360)
        ]
      end)

      expect_messages({"Ashmont      2 min", "Ashmont      4 min"})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "ignores predictions with no departure time or skipped schedule_relationship" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :alewife, seconds_until_departure: nil),
          prediction(destination: :alewife, arrival: 1, schedule_relationship: :skipped)
        ]
      end)

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when there are no predictions and only one source config, puts headways on the sign" do
      expect(Engine.Config.Mock, :headway_config, fn _, _ ->
        %{@headway_config | range_high: 14}
      end)

      expect_messages({"Southbound trains", "Every 11 to 14 min"})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is forced into headway mode but no alerts are present, displays headways" do
      expect(Engine.Config.Mock, :sign_config, fn _, _ -> :headway end)

      expect(Engine.Config.Mock, :headway_config, fn _, _ ->
        %{@headway_config | range_high: 14}
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 120)]
      end)

      expect_messages({"Southbound trains", "Every 11 to 14 min"})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is forced into headway mode but alerts are present, alert takes precedence" do
      expect(Engine.Config.Mock, :sign_config, fn _, _ -> :headway end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 120)]
      end)

      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :station_closure end)
      expect_messages({"No Southbound svc", ""})

      expect_audios([{:ad_hoc, {"No Southbound service.", :audio}}], [
        {"No Southbound service.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "generates empty messages if no headway is configured for some reason" do
      expect(Engine.Config.Mock, :headway_config, fn _, _ -> nil end)
      expect_messages({"", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "generates empty messages if outside of service hours" do
      expect(Engine.ScheduledHeadways.Mock, :display_headways?, fn _, _, _ -> false end)
      expect_messages({"", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "generates non-directional headway message at center/mezz signs" do
      expect(Engine.Config.Mock, :headway_config, 2, fn _, _ ->
        %{@headway_config | range_high: 14}
      end)

      expect_messages({"Red line trains", "Every 11 to 14 min"})
      Signs.Realtime.handle_info(:run_loop, @mezzanine_sign)
    end

    test "multi-route mezzanine, same headways" do
      expect(Engine.Config.Mock, :headway_config, 2, fn _, _ ->
        %{@headway_config | range_high: 14}
      end)

      expect_messages({"Trains", "Every 11 to 14 min"})
      Signs.Realtime.handle_info(:run_loop, @multi_route_mezzanine_sign)
    end

    test "when given two source lists, returns earliest result from each" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 130)]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :alewife, arrival: 10),
          prediction(destination: :alewife, arrival: 70)
        ]
      end)

      expect_messages({"Ashmont      2 min", "Alewife        ARR"})
      Signs.Realtime.handle_info(:run_loop, @mezzanine_sign)
    end

    test "sorts by arrival or departure depending on which is present" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :alewife, arrival: 240),
          prediction(destination: :alewife, seconds_until_departure: 480)
        ]
      end)

      expect_messages({"Alewife      4 min", "Alewife      8 min"})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "When the train is stopped a long time away, but not quite max time, shows stopped" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :mattapan, arrival: 1100, stopped: 8, trip_id: "1")]
      end)

      expect_messages(
        {[{"Mattapan   Stopped", 6}, {"Mattapan   8 stops", 6}, {"Mattapan      away", 6}], ""}
      )

      expect_audios(
        [{:canned, {"115", spaced(["501", "4100", "864", "533", "641", "5008", "534"]), :audio}}],
        [{"The next Mattapan train is stopped 8 stops away.", nil}]
      )

      assert {_, %{announced_stalls: [{"1", 8}]}} = Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "When the train is stopped a long time away from a terminal, shows max time instead of stopped" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            destination: :mattapan,
            seconds_until_departure: 2020,
            stopped: 8,
            type: :reverse
          )
        ]
      end)

      expect_messages({"Mattapan   30+ min", ""})
      Signs.Realtime.handle_info(:run_loop, @terminal_sign)
    end

    test "When the train is stopped at the terminal and departing in <= 60 seconds, shows BRD" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            destination: :mattapan,
            stopped: 0,
            seconds_until_arrival: -1,
            seconds_until_departure: 60,
            trip_id: "3"
          )
        ]
      end)

      expect_messages({"Mattapan       BRD", ""})

      expect_audios(
        [
          {:canned, {"109", ["501", "21000", "4100", "21000", "864", "21000", "544"], :audio}}
        ],
        [{"The next Mattapan train is now boarding.", nil}]
      )

      Signs.Realtime.handle_info(:run_loop, @terminal_sign)
    end

    test "When the train is stopped at the terminal and departing in more than 60 seconds, shows mins to departure" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            destination: :mattapan,
            stopped: 0,
            seconds_until_arrival: nil,
            seconds_until_departure: 91,
            trip_id: "3"
          )
        ]
      end)

      expect_messages({"Mattapan     2 min", ""})
      Signs.Realtime.handle_info(:run_loop, @terminal_sign)
    end

    test "When the train is stopped a long time away, shows max time instead of stopped" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :mattapan, arrival: 3700, stopped: 8)]
      end)

      expect_messages({"Mattapan   60+ min", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "only the first prediction in a source list can be BRD" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :mattapan, arrival: 0, stopped: 0, trip_id: "1"),
          prediction(destination: :mattapan, arrival: 100)
        ]
      end)

      expect_messages({"Mattapan       BRD", "Mattapan     2 min"})

      expect_audios(
        [{:canned, {"109", spaced(["501", "4100", "864", "544"]), :audio}}],
        [{"The next Mattapan train is now boarding.", nil}]
      )

      assert {_, %{announced_boardings: ["1"]}} = Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "Sorts boarding status to the top" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :boston_college, arrival: 200),
          prediction(destination: :cleveland_circle, arrival: 250, stopped: 0)
        ]
      end)

      expect_messages({"Clvlnd Cir     BRD", "Boston Col   3 min"})

      expect_audios(
        [{:canned, {"111", spaced(["501", "537", "507", "4203", "544"]), :audio}}],
        [{"The next C train to Cleveland Circle is now boarding.", nil}]
      )

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "allows ARR on second line" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :cleveland_circle, arrival: 15, stop_id: "1"),
          prediction(destination: :riverside, arrival: 16, stop_id: "1")
        ]
      end)

      expect_messages({"Clvlnd Cir     ARR", "Riverside      ARR"})

      expect_audios(
        [
          {:canned,
           {"114", spaced(["896", "903", "919", "904", "910", "21014", "925"]), :audio_visual}}
        ],
        [
          {"Attention passengers: The next C train to Cleveland Circle is now approaching. Please stand back from the platform edge.",
           [
             {"C train to Clvlnd Cir is", "now approaching. Please", 3},
             {"stand back from the", "platform edge.", 3}
           ]}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "doesn't sort 0 stops away to first for terminals when another departure is sooner" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :boston_college, seconds_until_departure: 250),
          prediction(destination: :cleveland_circle, seconds_until_departure: 300, stops_away: 0)
        ]
      end)

      expect_messages({"Boston Col   4 min", "Clvlnd Cir   5 min"})
      Signs.Realtime.handle_info(:run_loop, @terminal_sign)
    end

    test "Correctly orders BRD predictions between trains mid-trip and those starting their trip" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            destination: :riverside,
            stopped: 0,
            seconds_until_arrival: -30,
            seconds_until_departure: 60,
            trip_id: "1"
          ),
          prediction(
            destination: :riverside,
            stopped: 0,
            seconds_until_arrival: -15,
            seconds_until_departure: 75,
            trip_id: "2"
          ),
          prediction(
            destination: :boston_college,
            stopped: 0,
            seconds_until_arrival: nil,
            seconds_until_departure: 60,
            trip_id: "3"
          )
        ]
      end)

      expect_messages({"Riverside      BRD", "Boston Col     BRD"})

      expect_audios(
        [
          {:canned, {"111", spaced(["501", "538", "507", "4084", "544"]), :audio}},
          {:canned, {"111", spaced(["501", "536", "507", "4202", "544"]), :audio}}
        ],
        [
          {"The next D train to Riverside is now boarding.", nil},
          {"The next B train to Boston College is now boarding.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "prefers showing distinct destinations when present" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 120),
          prediction(destination: :ashmont, arrival: 500),
          prediction(destination: :braintree, arrival: 700)
        ]
      end)

      expect_messages({"Ashmont      2 min", "Braintree   12 min"})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "reads special boarding button announcement at Bowdoin" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 0, destination: :wonderland, stopped: 0)]
      end)

      expect_audios(
        [
          {:canned, {"109", spaced(["501", "4044", "864", "544"]), :audio}},
          {:canned, {"103", ["869"], :audio_visual}}
        ],
        [
          {"The next Wonderland train is now boarding.", nil},
          {"Attention Passengers: To board the next train, please push the button on either side of the door.",
           [
             {"Attention Passengers: To", "board the next train,", 3},
             {"please push the button", "on either side of the", 3},
             {"door.", "", 3}
           ]}
        ]
      )

      expect_messages({"Wonderland     BRD", ""})

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | pa_ess_loc: "BBOW",
          text_zone: "e",
          source_config: %{@sign.source_config | sources: [%{@src | direction_id: 1}]}
      })
    end

    test "announces approaching" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 45, trip_id: "1")]
      end)

      expect_messages({"Ashmont      1 min", ""})

      expect_audios(
        [{:canned, {"112", spaced(["896", "895", "920", "910", "21014", "925"]), :audio_visual}}],
        [
          {"Attention passengers: The next Ashmont train is now approaching. Please stand back from the platform edge.",
           [
             {"Ashmont train is now", "approaching. Please", 3},
             {"stand back from the", "platform edge.", 3}
           ]}
        ]
      )

      assert {_, %{announced_approachings: ["1"]}} = Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "doesn't announce approaching if already announced previously" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, arrival: 45, trip_id: "1")]
      end)

      expect_messages({"Alewife      1 min", ""})
      Signs.Realtime.handle_info(:run_loop, %{@sign | announced_approachings: ["1"]})
    end

    test "announces approaching for Green Line" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :cleveland_circle, arrival: 45)]
      end)

      expect_messages({"Clvlnd Cir   1 min", ""})

      expect_audios(
        [
          {:canned,
           {"114", spaced(["896", "903", "919", "904", "910", "21014", "925"]), :audio_visual}}
        ],
        [
          {"Attention passengers: The next C train to Cleveland Circle is now approaching. Please stand back from the platform edge.",
           [
             {"C train to Clvlnd Cir is", "now approaching. Please", 3},
             {"stand back from the", "platform edge.", 3}
           ]}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "announces next prediction if we weren't showing any before" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 120),
          prediction(destination: :ashmont, arrival: 240)
        ]
      end)

      expect_messages({"Ashmont      2 min", "Ashmont      4 min"})

      expect_audios(
        [{:canned, {"115", spaced(["501", "4016", "864", "503", "504", "5002", "505"]), :audio}}],
        [{"The next Ashmont train arrives in 2 minutes.", nil}]
      )

      Signs.Realtime.handle_info(:run_loop, %{@sign | prev_prediction_keys: []})
    end

    test "doesn't announce ordinary predictions if we had some last time" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 120)]
      end)

      expect_messages({"Ashmont      2 min", ""})
      Signs.Realtime.handle_info(:run_loop, %{@sign | prev_prediction_keys: [{"Red", 0}]})
    end

    test "announcements delay upcoming readouts" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 45, trip_id: "1")]
      end)

      expect_messages({"Ashmont      1 min", ""})

      expect_audios(
        [{:canned, {"112", spaced(["896", "895", "920", "910", "21014", "925"]), :audio_visual}}],
        [
          {"Attention passengers: The next Ashmont train is now approaching. Please stand back from the platform edge.",
           [
             {"Ashmont train is now", "approaching. Please", 3},
             {"stand back from the", "platform edge.", 3}
           ]}
        ]
      )

      assert {_, %{tick_read: 119}} =
               Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 20})
    end

    test "Announce approaching with crowding when condfidence high" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 45, destination: :forest_hills, trip_id: "1")]
      end)

      expect(Engine.Locations.Mock, :for_vehicle, 1, fn _ ->
        location(crowding_confidence: :high)
      end)

      expect_messages({"Frst Hills   1 min", ""})

      expect_audios(
        [{:canned, {"112", spaced(["896", "907", "920", "910", "21014", "925"]), :audio_visual}}],
        [
          {"Attention passengers: The next Forest Hills train is now approaching. Please stand back from the platform edge.",
           [
             {"Frst Hills train is now", "approaching. Please", 3},
             {"stand back from the", "platform edge.", 3}
           ]}
        ]
      )

      assert capture_log(fn ->
               Signs.Realtime.handle_info(:run_loop, @sign)
             end) =~ "crowding_description={:train_level, :crowded}"
    end

    test "Announce approaching without crowding when condfidence low" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 45, destination: :forest_hills)]
      end)

      expect(Engine.Locations.Mock, :for_vehicle, fn _ ->
        location(crowding_confidence: :low)
      end)

      expect_messages({"Frst Hills   1 min", ""})

      expect_audios(
        [{:canned, {"112", spaced(["896", "907", "920", "910", "21014", "925"]), :audio_visual}}],
        [
          {"Attention passengers: The next Forest Hills train is now approaching. Please stand back from the platform edge.",
           [
             {"Frst Hills train is now", "approaching. Please", 3},
             {"stand back from the", "platform edge.", 3}
           ]}
        ]
      )

      assert capture_log(fn ->
               Signs.Realtime.handle_info(:run_loop, @sign)
             end) =~ "crowding_description=nil"
    end

    test "reads predictions" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 120),
          prediction(destination: :ashmont, arrival: 240)
        ]
      end)

      expect_messages({"Ashmont      2 min", "Ashmont      4 min"})

      expect_audios(
        [
          {:canned, {"115", spaced(["501", "4016", "864", "503", "504", "5002", "505"]), :audio}},
          {:canned, {"115", spaced(["667", "4016", "864", "503", "504", "5004", "505"]), :audio}}
        ],
        [
          {"The next Ashmont train arrives in 2 minutes.", nil},
          {"The following Ashmont train arrives in 4 minutes.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0})
    end

    test "reads headways" do
      expect_audios([{:canned, {"184", ["5511", "5513"], :audio}}], [
        {"Southbound trains every 11 to 13 minutes.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0})
    end

    test "reads mixed predictions and headways" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 130)]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect_messages(
        {"Ashmont      2 min", [{"Southbound  trains every", 6}, {"Southbound  11 to 13 min", 6}]}
      )

      expect_audios(
        [
          {:canned, {"115", spaced(["501", "4016", "864", "503", "504", "5002", "505"]), :audio}},
          {:canned, {"184", ["5511", "5513"], :audio}}
        ],
        [
          {"The next Ashmont train arrives in 2 minutes.", nil},
          {"Southbound trains every 11 to 13 minutes.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@mezzanine_sign | tick_read: 0})
    end

    test "reads custom messages" do
      expect(Engine.Config.Mock, :sign_config, fn _, _ ->
        {:static_text, {"custom", "message"}}
      end)

      expect_messages({"custom", "message"})
      expect_audios([{:ad_hoc, {"custom message", :audio}}], [{"custom message", nil}])

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | tick_read: 0,
          announced_custom_text: "custom message"
      })
    end

    test "invalid custom messages" do
      expect(Engine.Config.Mock, :sign_config, fn _, _ ->
        {:static_text, {"bad^", "long long long long message"}}
      end)

      expect_messages({"bad", "long long long long mess"})

      expect_audios([{:ad_hoc, {"bad long long long long mess", :audio}}], [
        {"bad long long long long mess", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "reads alerts" do
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :shuttles_closed_station end)
      expect_messages({"No Southbound svc", "Use shuttle bus"})

      expect_audios([{:ad_hoc, {"No Southbound service. Use shuttle.", :audio}}], [
        {"No Southbound service. Use shuttle.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0, announced_alert: true})
    end

    test "reads approaching as 1 min" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 45, trip_id: "1"),
          prediction(destination: :ashmont, arrival: 130)
        ]
      end)

      expect_messages({"Ashmont      1 min", "Ashmont      2 min"})

      expect_audios(
        [
          {:canned, {"115", spaced(["501", "4016", "864", "503", "504", "5001", "532"]), :audio}},
          {:canned, {"115", spaced(["667", "4016", "864", "503", "504", "5002", "505"]), :audio}}
        ],
        [
          {"The next Ashmont train arrives in 1 minute.", nil},
          {"The following Ashmont train arrives in 2 minutes.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0, announced_approachings: ["1"]})
    end

    test "reads approaching as 1 minute when on the bottom line and a different headsign" do
      # Note: This should be the default behavior for reading approaching trains, rather than a
      # special case.
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 0, stopped: 0, trip_id: "1"),
          prediction(destination: :braintree, arrival: 45, trip_id: "2")
        ]
      end)

      expect_messages({"Ashmont        BRD", "Braintree    1 min"})

      expect_audios(
        [
          {:canned, {"109", spaced(["501", "4016", "864", "544"]), :audio}},
          {:canned, {"115", spaced(["501", "4021", "864", "503", "504", "5001", "532"]), :audio}}
        ],
        [
          {"The next Ashmont train is now boarding.", nil},
          {"The next Braintree train arrives in 1 minute.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | tick_read: 0,
          announced_approachings: ["1", "2"]
      })
    end

    test "reads both lines when the top line is arriving and heavy rail" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 15, trip_id: "1"),
          prediction(destination: :ashmont, arrival: 120)
        ]
      end)

      expect_messages({"Ashmont        ARR", "Ashmont      2 min"})

      expect_audios(
        [
          {:canned, {"109", spaced(["501", "4016", "864", "24055"]), :audio}},
          {:canned, {"115", spaced(["667", "4016", "864", "503", "504", "5002", "505"]), :audio}}
        ],
        [
          {"The next Ashmont train is now arriving.", nil},
          {"The following Ashmont train arrives in 2 minutes.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | tick_read: 0,
          announced_approachings: ["1"]
      })
    end

    test "reads both lines when the bottom line is arriving on a multi_source sign for heavy rail" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 120)]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, arrival: 15, trip_id: "1")]
      end)

      expect_messages({"Ashmont      2 min", "Alewife        ARR"})

      expect_audios(
        [
          {:canned, {"115", spaced(["501", "4016", "864", "503", "504", "5002", "505"]), :audio}},
          {:canned, {"109", spaced(["501", "4000", "864", "24055"]), :audio}}
        ],
        [
          {"The next Ashmont train arrives in 2 minutes.", nil},
          {"The next Alewife train is now arriving.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@mezzanine_sign | tick_read: 0})
    end

    test "doesn't read stopped message for following trains" do
      # Note: This behavior exists because we didn't have recorded audio to cover this case at the
      # time, but we should fix this so it works the same as other readouts.
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 120, stopped: 3, trip_id: "1"),
          prediction(destination: :ashmont, arrival: 130, stopped: 4, trip_id: "2")
        ]
      end)

      expect_messages(
        {[{"Ashmont    Stopped", 6}, {"Ashmont    3 stops", 6}, {"Ashmont       away", 6}],
         [{"Ashmont    Stopped", 6}, {"Ashmont    4 stops", 6}, {"Ashmont       away", 6}]}
      )

      expect_audios(
        [{:canned, {"115", spaced(["501", "4016", "864", "533", "641", "5003", "534"]), :audio}}],
        [{"The next Ashmont train is stopped 3 stops away.", nil}]
      )

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0, announced_stalls: ["1", "2"]})
    end

    test "doesn't read predictions after stopped message" do
      # Note: This should be changed to read both messages, so it's consistent with other cases.
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 120, stopped: 3, trip_id: "1"),
          prediction(destination: :ashmont, arrival: 130)
        ]
      end)

      expect_messages(
        {[{"Ashmont    Stopped", 6}, {"Ashmont    3 stops", 6}, {"Ashmont       away", 6}],
         "Ashmont      2 min"}
      )

      expect_audios(
        [{:canned, {"115", spaced(["501", "4016", "864", "533", "641", "5003", "534"]), :audio}}],
        [{"The next Ashmont train is stopped 3 stops away.", nil}]
      )

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0, announced_stalls: ["1"]})
    end

    test "JFK mezzanine special case" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, arrival: 240, stop_id: "70086")]
      end)

      expect_messages(
        {[{"Southbound trains", 6}, {"Alewife      4 min", 6}],
         [{"Every 11 to 13 min", 6}, {"on Ashmont platform", 6}]}
      )

      expect_audios(
        [
          {:canned, {"184", ["5511", "5513"], :audio}},
          {:canned,
           {"121",
            spaced(["501", "4000", "864", "503", "504", "5004", "505", "851", "4016", "529"]),
            :audio}}
        ],
        [
          {"Southbound trains every 11 to 13 minutes.", nil},
          {"The next Alewife train arrives in 4 minutes on the Ashmont platform.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@jfk_mezzanine_sign | tick_read: 0})
    end

    test "JFK mezzanine platform TBD soon" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 380)]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :alewife, arrival: 440, stop_id: "70086"),
          prediction(destination: :alewife, arrival: 650, stop_id: "70096"),
          prediction(destination: :alewife, arrival: 1000, stop_id: "70096")
        ]
      end)

      expect_messages(
        {"Ashmont      6 min", [{"Alewife      7 min", 6}, {"Alewife (Platform TBD)", 6}]}
      )

      expect_audios(
        [
          {:canned, {"115", spaced(["501", "4016", "864", "503", "504", "5006", "505"]), :audio}},
          {:canned,
           {"117", spaced(["501", "4000", "864", "503", "504", "5007", "505", "849"]), :audio}}
        ],
        [
          {"The next Ashmont train arrives in 6 minutes.", nil},
          {"The next Alewife train arrives in 7 minutes. We will announce the platform for boarding soon.",
           nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@jfk_mezzanine_sign | tick_read: 0})
    end

    test "JFK mezzanine platform TBD later" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 120)]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :alewife, arrival: 650, stop_id: "70086"),
          prediction(destination: :alewife, arrival: 1000, stop_id: "70096")
        ]
      end)

      expect_messages(
        {"Ashmont      2 min", [{"Alewife     11 min", 6}, {"Alewife (Platform TBD)", 6}]}
      )

      expect_audios(
        [
          {:canned, {"115", spaced(["501", "4016", "864", "503", "504", "5002", "505"]), :audio}},
          {:canned,
           {"117", spaced(["501", "4000", "864", "503", "504", "5011", "505", "857"]), :audio}}
        ],
        [
          {"The next Ashmont train arrives in 2 minutes.", nil},
          {"The next Alewife train arrives in 11 minutes. We will announce the platform for boarding when the train is closer.",
           nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@jfk_mezzanine_sign | tick_read: 0})
    end

    test "JFK mezzanine shows platform when all predictions to Alewife use same platform" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 120)]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :alewife, arrival: 380, stop_id: "70086"),
          prediction(destination: :alewife, arrival: 650, stop_id: "70086"),
          prediction(destination: :alewife, arrival: 750, stop_id: "70086"),
          prediction(destination: :alewife, arrival: 660, stop_id: "70086"),
          prediction(destination: :alewife, arrival: 760, stop_id: "70086")
        ]
      end)

      expect_messages(
        {"Ashmont      2 min", [{"Alewife (A)  6 min", 6}, {"Alewife (Ashmont plat)", 6}]}
      )

      expect_audios(
        [
          {:canned, {"115", spaced(["501", "4016", "864", "503", "504", "5002", "505"]), :audio}},
          {:canned,
           {"121",
            spaced(["501", "4000", "864", "503", "504", "5006", "505", "851", "4016", "529"]),
            :audio}}
        ],
        [
          {"The next Ashmont train arrives in 2 minutes.", nil},
          {"The next Alewife train arrives in 6 minutes on the Ashmont platform.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@jfk_mezzanine_sign | tick_read: 0})
    end

    test "prevents showing predictions that count up by 1" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 180, destination: :ashmont)]
      end)

      expect_messages({"Ashmont      2 min", ""})

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | prev_predictions: [prediction(arrival: 120, destination: :ashmont)]
      })
    end

    test "When sign in full am suppression, show timestamp" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 180, destination: :ashmont)]
      end)

      expect_messages({"Southbound train", "due 5:00"})
      expect(Engine.ScheduledHeadways.Mock, :display_headways?, fn _, _, _ -> false end)

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | current_time_fn: fn -> datetime(~T[04:00:00]) end
      })
    end

    test "When sign in partial am suppression shows mid-trip and terminal predictions but filters out reverse predictions" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 120, type: :reverse),
          prediction(destination: :ashmont, arrival: 240, type: :terminal)
        ]
      end)

      expect_messages({"Ashmont      4 min", ""})

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | current_time_fn: fn -> datetime(~T[04:30:00]) end
      })
    end

    test "When sign in partial am suppression, no valid predictions, and within range of upper headway, show headways" do
      expect(Engine.Config.Mock, :headway_config, fn _, _ ->
        %{@headway_config | range_low: 9}
      end)

      expect_messages({"Southbound trains", "Every 9 to 13 min"})

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | current_time_fn: fn -> datetime(~T[04:50:00]) end
      })
    end

    test "When sign in partial am suppression, no valid predictions, but not within range of upper headway, show timestamp" do
      expect_messages({"Southbound train", "due 5:00"})
      expect(Engine.ScheduledHeadways.Mock, :display_headways?, fn _, _, _ -> false end)

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | current_time_fn: fn -> datetime(~T[04:45:00]) end
      })
    end

    test "When sign in partial am suppression, filters stopped predictions based on prediction type" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 120, stopped: 2, type: :reverse),
          prediction(
            destination: :ashmont,
            arrival: 240,
            stopped: 3,
            trip_id: "1",
            type: :terminal
          )
        ]
      end)

      expect_messages(
        {[{"Ashmont    Stopped", 6}, {"Ashmont    3 stops", 6}, {"Ashmont       away", 6}], ""}
      )

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | current_time_fn: fn -> datetime(~T[04:30:00]) end,
          announced_stalls: [{"1", 3}]
      })
    end

    test "mezzanine sign, full am suppression" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 180, destination: :ashmont)]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)
      expect(Engine.ScheduledHeadways.Mock, :display_headways?, 2, fn _, _, _ -> false end)

      expect_messages(
        {[{"Northbound train", 6}, {"Southbound train", 6}], [{"due 5:00", 6}, {"due 5:00", 6}]}
      )

      Signs.Realtime.handle_info(:run_loop, %{
        @mezzanine_sign
        | current_time_fn: fn -> datetime(~T[04:00:00]) end
      })
    end

    test "mezzanine sign, one line in full am suppression, one line in partial am suppression defaulting to headways" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 180, destination: :ashmont, type: :reverse)]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect(Engine.ScheduledHeadways.Mock, :get_first_scheduled_departure, fn _ ->
        datetime(~T[05:30:00])
      end)

      expect(Engine.ScheduledHeadways.Mock, :display_headways?, fn _, _, _ -> false end)

      expect(Engine.ScheduledHeadways.Mock, :get_first_scheduled_departure, fn _ ->
        datetime(~T[05:00:00])
      end)

      expect(Engine.ScheduledHeadways.Mock, :display_headways?, fn _, _, _ -> true end)

      expect_messages(
        {[{"Northbound train", 6}, {"Southbound trains", 6}],
         [{"due 5:30", 6}, {"Every 11 to 13 min", 6}]}
      )

      Signs.Realtime.handle_info(:run_loop, %{
        @mezzanine_sign
        | current_time_fn: fn -> datetime(~T[04:50:00]) end
      })
    end

    test "mezzanine sign, early am, both lines in partial am suppression defaulting to headways" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 180, destination: :ashmont, type: :reverse)]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect(Engine.Config.Mock, :headway_config, 2, fn _, _ ->
        %{@headway_config | range_low: 9}
      end)

      expect_messages({"Red line trains", "Every 9 to 13 min"})

      expect_audios([{:ad_hoc, {"Red line trains every 9 to 13 minutes.", :audio}}], [
        {"Red line trains every 9 to 13 minutes.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, %{
        @mezzanine_sign
        | current_time_fn: fn -> datetime(~T[04:50:00]) end,
          tick_read: 0
      })
    end

    test "mezzanine sign, early am, one line showing prediction, one line default to paging headway" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 180, destination: :ashmont)]
      end)

      expect_messages(
        {"Ashmont      3 min", [{"Northbound  trains every", 6}, {"Northbound  11 to 13 min", 6}]}
      )

      Signs.Realtime.handle_info(:run_loop, %{
        @mezzanine_sign
        | current_time_fn: fn -> datetime(~T[04:50:00]) end
      })
    end

    test "mezzanine sign, early am, one line showing prediction, one line showing timestamp" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 180, destination: :ashmont)]
      end)

      expect(Engine.ScheduledHeadways.Mock, :display_headways?, fn _, _, _ -> false end)

      expect_messages({"Ashmont      3 min", "Northbound due 5:00"})

      Signs.Realtime.handle_info(:run_loop, %{
        @mezzanine_sign
        | current_time_fn: fn -> datetime(~T[04:30:00]) end
      })
    end

    test "JFK mezzanine, early am, southbound on timestamp and Alewife on platform prediction" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, arrival: 240, stop_id: "70086")]
      end)

      expect(Engine.ScheduledHeadways.Mock, :display_headways?, fn _, _, _ -> false end)

      expect_messages(
        {[{"Southbound train", 6}, {"Alewife      4 min", 6}],
         [{"due 5:00", 6}, {"on Ashmont platform", 6}]}
      )

      Signs.Realtime.handle_info(:run_loop, %{
        @jfk_mezzanine_sign
        | current_time_fn: fn -> datetime(~T[04:30:00]) end
      })
    end

    test "JFK mezzanine, early am, southbound on headways and Alewife on platform prediction" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, arrival: 240, stop_id: "70086")]
      end)

      expect_messages(
        {[{"Southbound trains", 6}, {"Alewife      4 min", 6}],
         [{"Every 11 to 13 min", 6}, {"on Ashmont platform", 6}]}
      )

      Signs.Realtime.handle_info(:run_loop, %{
        @jfk_mezzanine_sign
        | current_time_fn: fn -> datetime(~T[04:50:00]) end
      })
    end

    test "JFK mezzanine, early am, filtered platform prediction and headways returns full page headways" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            destination: :alewife,
            arrival: 240,
            stop_id: "70086",
            type: :reverse
          )
        ]
      end)

      expect_messages({"Red line trains", "Every 11 to 13 min"})

      Signs.Realtime.handle_info(:run_loop, %{
        @jfk_mezzanine_sign
        | current_time_fn: fn -> datetime(~T[04:50:00]) end
      })
    end

    test "JFK mezzanine, early am, valid platform prediction and non suppressed headway gets passed through" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, arrival: 240, stop_id: "70086")]
      end)

      expect(Engine.ScheduledHeadways.Mock, :get_first_scheduled_departure, fn _ ->
        datetime(~T[04:30:00])
      end)

      expect(Engine.ScheduledHeadways.Mock, :get_first_scheduled_departure, fn _ ->
        datetime(~T[05:00:00])
      end)

      expect_messages(
        {[{"Southbound trains", 6}, {"Alewife      4 min", 6}],
         [{"Every 11 to 13 min", 6}, {"on Ashmont platform", 6}]}
      )

      Signs.Realtime.handle_info(:run_loop, %{
        @jfk_mezzanine_sign
        | current_time_fn: fn -> datetime(~T[04:50:00]) end
      })
    end

    test "Identifies new Red Line Cars" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            destination: :ashmont,
            arrival: 45,
            trip_id: "1",
            multi_carriage_details:
              make_carriage_details([
                {"1900", "1"},
                {"1901", "1"},
                {"1902", "1"},
                {"1903", "1"},
                {"1905", "1"},
                {"1904", "1"}
              ])
          )
        ]
      end)

      expect_messages({"Ashmont      1 min", ""})

      expect_audios(
        [
          {:canned,
           {"115", spaced(["896", "895", "920", "910", "21012", "893", "21014", "925"]),
            :audio_visual}}
        ],
        [
          {"Attention passengers: The next Ashmont train is now approaching, with all new Red Line cars. Please stand back from the platform edge.",
           [
             {"Ashmont train is now", "approaching, with all", 3},
             {"new Red Line cars.", "Please stand back from", 3},
             {"the platform edge.", "", 3}
           ]}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "Identifies old Red Line Cars" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            destination: :ashmont,
            arrival: 45,
            trip_id: "1",
            multi_carriage_details:
              make_carriage_details([
                {"1706", "1"},
                {"1707", "1"},
                {"1502", "1"},
                {"1503", "1"},
                {"1750", "1"},
                {"1751", "1"}
              ])
          )
        ]
      end)

      expect_messages({"Ashmont      1 min", ""})

      expect_audios(
        [{:canned, {"112", spaced(["896", "895", "920", "910", "21014", "925"]), :audio_visual}}],
        [
          {"Attention passengers: The next Ashmont train is now approaching. Please stand back from the platform edge.",
           [
             {"Ashmont train is now", "approaching. Please", 3},
             {"stand back from the", "platform edge.", 3}
           ]}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "announces four-car trains" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :braintree, arrival: 45, four_cars?: true),
          prediction(destination: :ashmont, arrival: 180)
        ]
      end)

      expect_messages({"Braintree    1 min", "4 cars     Move to front"})

      expect_audios(
        [{:canned, {"112", spaced(["923", "902", "920", "924", "21014", "922"]), :audio_visual}}],
        [
          {"Attention passengers: The next Braintree train is now approaching. It is a shorter 4-car train. Move toward the front of the train to board, and stand back from the platform edge.",
           [
             {"Shorter 4 car Braintree", "train now approaching.", 3},
             {"Please move to front of", "the train to board.", 3}
           ]}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "shows four-car messages" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :braintree, arrival: 130, four_cars?: true),
          prediction(destination: :ashmont, arrival: 180)
        ]
      end)

      expect_messages({"Braintree    2 min", "4 cars     Move to front"})

      expect_audios(
        [
          {:canned,
           {"117", spaced(["501", "4021", "864", "503", "504", "5002", "505", "922"]), :audio}}
        ],
        [
          {"The next Braintree train arrives in 2 minutes. It is a shorter 4-car train. Move toward the front of the train to board, and stand back from the platform edge.",
           nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0})
    end

    test "doesn't show four-car messages at terminals when not boarding" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            stop_id: "70061",
            destination: :braintree,
            seconds_until_departure: 130,
            four_cars?: true
          ),
          prediction(destination: :braintree, seconds_until_departure: 180)
        ]
      end)

      expect_messages({"Braintree    2 min", "Braintree    3 min"})

      expect_audios(
        [
          {:canned, {"115", spaced(["501", "4021", "864", "502", "504", "5002", "505"]), :audio}},
          {:canned, {"115", spaced(["667", "4021", "864", "502", "504", "5003", "505"]), :audio}}
        ],
        [
          {"The next Braintree train departs in 2 minutes.", nil},
          {"The following Braintree train departs in 3 minutes.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@alewife_sign | tick_read: 0})
    end

    test "announces special four car train boarding message at Braintree/Alewife" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            stop_id: "70061",
            destination: :braintree,
            stopped: 0,
            seconds_until_arrival: -1,
            seconds_until_departure: 60,
            four_cars?: true
          ),
          prediction(destination: :braintree, seconds_until_departure: 180)
        ]
      end)

      expect_messages({"Braintree      BRD", "Braintree    3 min"})

      expect_audios(
        [
          {:canned, {"111", spaced(["501", "4021", "864", "544", "926"]), :audio}}
        ],
        [
          {"The next Braintree train is now boarding. It is a shorter 4-car train. You may have to move to a different part of the platform to board.",
           nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@alewife_sign | tick_read: 0})
    end

    test "shows four-car messages at Ashmont northbound terminal specifically" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            stop_id: "70094",
            destination: :alewife,
            seconds_until_departure: 130,
            four_cars?: true
          )
        ]
      end)

      expect_messages({"Alewife      2 min", "4 cars     Move to front"})

      expect_audios(
        [
          {:canned,
           {"117", spaced(["501", "4000", "864", "502", "504", "5002", "505", "922"]), :audio}}
        ],
        [
          {"The next Alewife train departs in 2 minutes. It is a shorter 4-car train. Move toward the front of the train to board, and stand back from the platform edge.",
           nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@ashmont_sign | tick_read: 0})
    end

    test "doesn't show four-car messages at mezzanines" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :braintree, seconds_until_departure: 130, four_cars?: true)]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, seconds_until_departure: 430, four_cars?: true)]
      end)

      expect_messages({"Braintree    2 min", "Alewife      7 min"})

      expect_audios(
        [
          {:canned, {"115", spaced(["501", "4021", "864", "503", "504", "5002", "505"]), :audio}},
          {:canned, {"115", spaced(["501", "4000", "864", "503", "504", "5007", "505"]), :audio}}
        ],
        [
          {"The next Braintree train arrives in 2 minutes.", nil},
          {"The next Alewife train arrives in 7 minutes.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@mezzanine_sign | tick_read: 0})
    end

    test "mezzanine sign, headways and shuttle alert" do
      expect(Engine.Config.Mock, :sign_config, fn _, _ -> :headway end)
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :none end)
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :shuttles_closed_station end)

      expect_messages({
        [{"Northbound trains", 6}, {"No Southbound svc", 6}],
        [{"Every 11 to 13 min", 6}, {"Use shuttle bus", 6}]
      })

      expect_audios([{:ad_hoc, {"No Southbound service. Use shuttle.", :audio}}], [
        {"No Southbound service. Use shuttle.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, @multi_route_mezzanine_sign)
    end

    test "mezzanine sign, non-shuttle alert and headways" do
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :suspension_closed_station end)
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :none end)

      expect_messages(
        {"Northbound  no svc", [{"Southbound  trains every", 6}, {"Southbound  11 to 13 min", 6}]}
      )

      expect_audios([{:ad_hoc, {"No Northbound service.", :audio}}], [
        {"No Northbound service.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, @mezzanine_sign)
    end

    test "multi-route mezzanine sign, different headways" do
      expect(Engine.Config.Mock, :headway_config, fn _, _ -> %{@headway_config | range_low: 9} end)

      expect(Engine.Config.Mock, :headway_config, fn _, _ -> %{@headway_config | range_low: 7} end)

      expect_messages(
        {[{"Northbound trains", 6}, {"Southbound trains", 6}],
         [{"Every 9 to 13 min", 6}, {"Every 7 to 13 min", 6}]}
      )

      Signs.Realtime.handle_info(:run_loop, @multi_route_mezzanine_sign)
    end

    test "mezzanine sign, shuttle alert flips to bottom" do
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :shuttles_closed_station end)
      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :none end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, arrival: 240)]
      end)

      expect_messages(
        {"Alewife      4 min", [{"Northbound    no service", 6}, {"Northbound   use shuttle", 6}]}
      )

      expect_audios([{:ad_hoc, {"No Northbound service. Use shuttle.", :audio}}], [
        {"No Northbound service. Use shuttle.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, @mezzanine_sign)
    end

    test "JFK platform" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :alewife, stop_id: "70086", arrival: 240),
          prediction(destination: :alewife, stop_id: "70086", arrival: 540)
        ]
      end)

      expect_messages({"Alewife      4 min", "Alewife      9 min"})

      expect_audios(
        [
          {:canned,
           {"121",
            spaced(["501", "4000", "864", "851", "4016", "529", "503", "504", "5004", "505"]),
            :audio}},
          {:canned,
           {"121",
            spaced(["667", "4000", "864", "851", "4016", "529", "503", "504", "5009", "505"]),
            :audio}}
        ],
        [
          {"The next Alewife train on the Ashmont platform arrives in 4 minutes.", nil},
          {"The following Alewife train on the Ashmont platform arrives in 9 minutes.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0})
    end

    test "track numbers" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :forest_hills, stop_id: "Oak Grove-01", arrival: 240)]
      end)

      expect_messages({[{"Frst Hills   4 min", 6}, {"Frst Hills   Trk 1", 6}], ""})

      expect_audios(
        [
          {:canned,
           {"117", spaced(["501", "4043", "864", "503", "504", "5004", "505", "541"]), :audio}}
        ],
        [{"The next Forest Hills train arrives in 4 minutes on track 1.", nil}]
      )

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0})
    end

    test "When train is stopped at a non-terminal and we are very close to the departure time, show BRD regardless of stopped_at_predicted_stop" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            destination: :forest_hills,
            seconds_until_arrival: -1,
            seconds_until_departure: 9,
            trip_id: "3",
            stopped_at_predicted_stop?: false
          )
        ]
      end)

      expect_messages({"Frst Hills     BRD", ""})

      expect_audios(
        [
          {:canned, {"109", spaced(["501", "4043", "864", "544"]), :audio}}
        ],
        [{"The next Forest Hills train is now boarding.", nil}]
      )

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0})
    end
  end

  describe "decrement_ticks/1" do
    test "decrements all the ticks when all of them dont need to be reset" do
      sign = %{
        @sign
        | tick_read: 100
      }

      sign = Signs.Realtime.decrement_ticks(sign)

      assert sign.tick_read == 99
    end
  end

  describe "Union Sq alert messaging" do
    setup do
      stub(Engine.Config.Mock, :sign_config, fn _, _ -> :auto end)
      stub(Engine.Alerts.Mock, :min_stop_status, fn _ -> :shuttles_transfer_station end)
      stub(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)
      stub(Engine.LastTrip.Mock, :is_last_trip?, fn _ -> false end)
      stub(Engine.LastTrip.Mock, :get_recent_departures, fn _ -> %{} end)

      stub(Engine.ScheduledHeadways.Mock, :get_first_scheduled_departure, fn _ ->
        datetime(~T[05:00:00])
      end)

      stub(Engine.ScheduledHeadways.Mock, :get_last_scheduled_departure, fn _ ->
        datetime(~D[2023-01-02], ~T[02:00:00])
      end)

      :ok
    end

    test "Defaults to use routes message" do
      sign = %{
        @sign
        | pa_ess_loc: "GUNS",
          text_zone: "x"
      }

      expect_messages({"No Southbound svc", "Use Routes 87, 91 or 109"})

      expect_audios([{:ad_hoc, {"No Southbound service. Use Routes 87, 91, or 109", :audio}}], [
        {"No Southbound service. Use Routes 87, 91, or 109", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, sign)
    end
  end

  describe "Last Trip of the Day" do
    setup do
      stub(Engine.Config.Mock, :sign_config, fn _, _ -> :auto end)
      stub(Engine.Alerts.Mock, :min_stop_status, fn _ -> :none end)
      stub(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)
      stub(Engine.LastTrip.Mock, :is_last_trip?, fn _ -> true end)

      stub(Engine.LastTrip.Mock, :get_recent_departures, fn _ ->
        %{"a" => datetime(~D[2022-12-31], ~T[23:55:00])}
      end)

      stub(Engine.Config.Mock, :headway_config, fn _, _ -> @headway_config end)
      stub(Engine.ScheduledHeadways.Mock, :display_headways?, fn _, _, _ -> false end)

      stub(Engine.ScheduledHeadways.Mock, :get_first_scheduled_departure, fn _ ->
        datetime(~D[2022-12-31], ~T[05:00:00])
      end)

      stub(Engine.ScheduledHeadways.Mock, :get_last_scheduled_departure, fn _ ->
        datetime(~T[02:00:00])
      end)

      :ok
    end

    test "Platform is closed" do
      sign = %{
        @sign
        | tick_read: 0,
          current_time_fn: &fake_midnight_fn/0
      }

      expect_messages({"Service ended", "No Southbound trains"})

      expect_audios([{:canned, {"107", spaced(["884", "787", "882"]), :audio}}], [
        {"This platform is closed. Southbound service has ended for the night.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, sign)
    end

    test "multi-route mezzanine sign, both sides closed" do
      expect_messages({"Station closed", "Service ended for night"})

      expect_audios([{:canned, {"105", spaced(["864", "882"]), :audio}}], [
        {"Train service has ended for the night.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, %{
        @multi_route_mezzanine_sign
        | tick_read: 0,
          current_time_fn: &fake_midnight_fn/0
      })
    end

    test "single-route mezzanine sign, both sides closed" do
      sign = %{
        @mezzanine_sign
        | tick_read: 0,
          current_time_fn: &fake_midnight_fn/0
      }

      expect_messages({"No Red Line", "Service ended for night"})

      expect_audios([{:canned, {"105", spaced(["3005", "882"]), :audio}}], [
        {"Red line service has ended for the night.", nil}
      ])

      Signs.Realtime.handle_info(:run_loop, sign)
    end

    test "No service goes on bottom line when top line fits in 18 chars or less" do
      sign = %{
        @mezzanine_sign
        | tick_read: 0,
          announced_stalls: [{"a", 8}],
          current_time_fn: &fake_midnight_fn/0
      }

      expect(Engine.Predictions.Mock, :for_stop, fn "1", 0 ->
        [prediction(destination: :mattapan, arrival: 1100, stopped: 8, trip_id: "a")]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn "2", 0 ->
        []
      end)

      expect(Engine.LastTrip.Mock, :get_recent_departures, fn "1" ->
        %{"a" => datetime(~D[2022-12-31], ~T[23:55:00])}
      end)

      expect(Engine.LastTrip.Mock, :get_recent_departures, fn "2" ->
        %{"b" => datetime(~D[2022-12-31], ~T[23:55:00])}
      end)

      expect(Engine.LastTrip.Mock, :get_recent_departures, fn "1" ->
        %{"a" => datetime(~D[2022-12-31], ~T[23:55:00])}
      end)

      expect(Engine.LastTrip.Mock, :get_recent_departures, fn "2" ->
        %{"b" => datetime(~D[2022-12-31], ~T[23:55:00])}
      end)

      expect(Engine.LastTrip.Mock, :is_last_trip?, fn "a" -> false end)
      expect(Engine.LastTrip.Mock, :is_last_trip?, fn "b" -> true end)

      expect_messages(
        {[{"Mattapan   Stopped", 6}, {"Mattapan   8 stops", 6}, {"Mattapan      away", 6}],
         "Southbound     Svc ended"}
      )

      expect_audios(
        [
          {:canned, {"115", spaced(["501", "4100", "864", "533", "641", "5008", "534"]), :audio}},
          {:canned, {"105", spaced(["787", "882"]), :audio}}
        ],
        [
          {"The next Mattapan train is stopped 8 stops away.", nil},
          {"Southbound service has ended for the night.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, sign)
    end

    test "No service goes on top line when bottom line needs more than 18 characters" do
      sign = %{
        @jfk_mezzanine_sign
        | tick_read: 0,
          current_time_fn: &fake_midnight_fn/0
      }

      expect(Engine.Predictions.Mock, :for_stop, fn "1", 0 ->
        []
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn "70086", 1 ->
        [prediction(destination: :alewife, arrival: 240, stop_id: "70086")]
      end)

      expect(Engine.LastTrip.Mock, :get_recent_departures, fn "1" ->
        %{"a" => datetime(~D[2022-12-31], ~T[23:55:00])}
      end)

      expect(Engine.LastTrip.Mock, :get_recent_departures, fn "70086" ->
        %{"b" => datetime(~D[2022-12-31], ~T[23:55:00])}
      end)

      expect(Engine.LastTrip.Mock, :get_recent_departures, fn "1" ->
        %{"a" => datetime(~D[2022-12-31], ~T[23:55:00])}
      end)

      expect(Engine.LastTrip.Mock, :get_recent_departures, fn "70086" ->
        %{"b" => datetime(~D[2022-12-31], ~T[23:55:00])}
      end)

      expect(Engine.LastTrip.Mock, :is_last_trip?, fn "a" -> true end)
      expect(Engine.LastTrip.Mock, :is_last_trip?, fn "b" -> false end)

      expect_messages(
        {"Southbound  No Svc", [{"Alewife (A)  4 min", 6}, {"Alewife (Ashmont plat)", 6}]}
      )

      expect_audios(
        [
          {:canned, {"105", spaced(["787", "882"]), :audio}},
          {:canned,
           {"121",
            spaced(["501", "4000", "864", "503", "504", "5004", "505", "851", "4016", "529"]),
            :audio}}
        ],
        [
          {"Southbound service has ended for the night.", nil},
          {"The next Alewife train arrives in 4 minutes on the Ashmont platform.", nil}
        ]
      )

      Signs.Realtime.handle_info(:run_loop, sign)
    end

    test "Red line trunk service doesn't end after one last trip" do
      expect_messages({"", ""})

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | source_config: %{@sign.source_config | headway_group: "red_trunk"}
      })
    end

    test "Red line trunk service ends after two last trips" do
      expect(Engine.LastTrip.Mock, :get_recent_departures, 2, fn _ ->
        %{
          "a" => datetime(~D[2022-12-31], ~T[23:55:00]),
          "b" => datetime(~D[2022-12-31], ~T[23:55:00])
        }
      end)

      expect_messages({"Service ended", "No Southbound trains"})

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | source_config: %{@sign.source_config | headway_group: "red_trunk"},
          current_time_fn: &fake_midnight_fn/0
      })
    end
  end

  describe "PA messages" do
    setup do
      stub(Engine.Config.Mock, :sign_config, fn _, _ -> :auto end)
      stub(Engine.Config.Mock, :headway_config, fn _, _ -> @headway_config end)
      stub(Engine.Alerts.Mock, :min_stop_status, fn _ -> :none end)
      stub(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)
      stub(Engine.ScheduledHeadways.Mock, :display_headways?, fn _, _, _ -> true end)
      stub(Engine.Locations.Mock, :for_vehicle, fn _ -> nil end)
      stub(Engine.LastTrip.Mock, :is_last_trip?, fn _ -> false end)
      stub(Engine.LastTrip.Mock, :get_recent_departures, fn _ -> %{} end)

      stub(Engine.ScheduledHeadways.Mock, :get_first_scheduled_departure, fn _ ->
        DateTime.new!(~D[2022-12-31], ~T[05:00:00], "Etc/UTC")
      end)

      :ok
    end

    test "Plays message if no prior plays" do
      pa_message = %PaMessages.PaMessage{
        id: 1,
        visual_text: "A PA Message",
        audio_text: "A PA Message"
      }

      assert {:reply, {_, true}, _} =
               Signs.Realtime.handle_call({:play_pa_message, pa_message}, nil, @sign)
    end

    test "Plays message if interval has passed" do
      pa_message = %PaMessages.PaMessage{
        id: 1,
        visual_text: "A PA Message",
        audio_text: "A PA Message",
        interval_in_ms: 120_000
      }

      sign = %{@sign | pa_message_plays: %{1 => ~U[2024-06-10 12:00:00.000Z]}}

      assert {:reply, {_, true}, _} =
               Signs.Realtime.handle_call({:play_pa_message, pa_message}, nil, sign)
    end

    test "Does not play if less than interval has passed" do
      pa_message = %PaMessages.PaMessage{
        id: 1,
        visual_text: "A PA Message",
        audio_text: "A PA Message",
        interval_in_ms: 120_000
      }

      sign = %{@sign | pa_message_plays: %{1 => DateTime.utc_now()}}

      assert {:reply, {_, false}, _} =
               Signs.Realtime.handle_call({:play_pa_message, pa_message}, nil, sign)
    end
  end

  describe "Overnight Period" do
    setup do
      stub(Engine.Config.Mock, :sign_config, fn _, _ -> :auto end)
      stub(Engine.Config.Mock, :headway_config, fn _, _ -> @headway_config end)
      stub(Engine.Alerts.Mock, :min_stop_status, fn _ -> :none end)
      stub(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)
      stub(Engine.ScheduledHeadways.Mock, :display_headways?, fn _, _, _ -> true end)
      stub(Engine.Locations.Mock, :for_vehicle, fn _ -> nil end)
      stub(Engine.LastTrip.Mock, :is_last_trip?, fn _ -> false end)
      stub(Engine.LastTrip.Mock, :get_recent_departures, fn _ -> %{} end)

      stub(Engine.ScheduledHeadways.Mock, :get_first_scheduled_departure, fn _ ->
        datetime(~D[2023-01-01], ~T[05:00:00])
      end)

      stub(Engine.ScheduledHeadways.Mock, :get_last_scheduled_departure, fn _ ->
        datetime(~D[2023-01-02], ~T[02:00:00])
      end)

      :ok
    end

    test "is not overnight period if last scheduled departure or first scheduled departure is nil" do
      stub(Engine.ScheduledHeadways.Mock, :get_first_scheduled_departure, fn _ ->
        nil
      end)

      stub(Engine.ScheduledHeadways.Mock, :get_last_scheduled_departure, fn _ ->
        nil
      end)

      expect(Engine.Config.Mock, :sign_config, fn _, _ -> :headway end)

      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :station_closure end)

      expect_messages({"No Southbound svc", ""})
      expect(PaEss.Updater.Mock, :play_message, 1, fn _, _, _, _, _ -> :ok end)

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | current_time_fn: fn -> datetime(~D[2023-01-02], ~T[03:00:00]) end
      })
    end

    test "is not overnight period if in the thirty minute buffer" do
      expect(Engine.Config.Mock, :sign_config, fn _, _ -> :headway end)

      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :station_closure end)

      expect_messages({"No Southbound svc", ""})
      expect(PaEss.Updater.Mock, :play_message, 1, fn _, _, _, _, _ -> :ok end)

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | current_time_fn: fn -> datetime(~D[2023-01-02], ~T[02:30:00]) end
      })
    end

    test "does not play alerts when in the overnight period" do
      expect(Engine.Config.Mock, :sign_config, fn _, _ -> :headway end)

      expect(Engine.Alerts.Mock, :min_stop_status, fn _ -> :station_closure end)

      expect_messages({"Southbound trains", "Every 11 to 13 min"})
      expect(PaEss.Updater.Mock, :play_message, 0, fn _, _, _, _, _ -> :ok end)

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | current_time_fn: fn -> datetime(~D[2023-01-02], ~T[03:00:00]) end
      })
    end

    test "still shows predictions if they exist during overnight period" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 180, destination: :ashmont)]
      end)

      expect_messages({"Ashmont      3 min", ""})

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | current_time_fn: fn -> datetime(~D[2023-01-02], ~T[03:00:00]) end
      })
    end

    test "does not show custom text during overnight period" do
      expect(Engine.Config.Mock, :sign_config, fn _, _ ->
        {:static_text, {"custom", "message"}}
      end)

      expect_messages({"", ""})
      expect(PaEss.Updater.Mock, :play_message, 0, fn _, _, _, _, _ -> :ok end)

      Signs.Realtime.handle_info(:run_loop, %{
        @mezzanine_sign
        | current_time_fn: fn -> datetime(~D[2023-01-02], ~T[03:00:00]) end
      })
    end
  end

  defp expect_messages(messages) do
    expect(PaEss.Updater.Mock, :set_background_message, fn _, top, bottom ->
      assert {top, bottom} == messages
      :ok
    end)
  end

  defp expect_audios(audios, tts_audios) do
    expect(PaEss.Updater.Mock, :play_message, fn _, list, tts_list, _, _ ->
      assert audios == list
      assert tts_audios == tts_list
      :ok
    end)
  end

  defp prediction(opts) do
    opts =
      opts ++
        case Keyword.get(opts, :destination) do
          :alewife -> [route_id: "Red", direction_id: 1]
          :ashmont -> [route_id: "Red", direction_id: 0, destination_stop_id: "70085"]
          :braintree -> [route_id: "Red", direction_id: 0, destination_stop_id: "70095"]
          :southbound -> [route_id: "Red", direction_id: 0, destination_stop_id: "70083"]
          :mattapan -> [route_id: "Mattapan", direction_id: 0]
          :boston_college -> [route_id: "Green-B", direction_id: 0]
          :cleveland_circle -> [route_id: "Green-C", direction_id: 0]
          :riverside -> [route_id: "Green-D", direction_id: 0]
          :wonderland -> [route_id: "Blue", direction_id: 1]
          :forest_hills -> [route_id: "Orange", direction_id: 0]
          nil -> []
        end

    opts =
      opts ++
        case Keyword.get(opts, :arrival) do
          nil -> []
          sec -> [seconds_until_arrival: sec, seconds_until_departure: sec + 30]
        end

    opts =
      opts ++
        case Keyword.get(opts, :stopped) do
          nil ->
            []

          0 ->
            [stopped_at_predicted_stop: true]

          stops ->
            [stopped_at_predicted_stop: false, boarding_status: "Stopped #{stops} stop away"]
        end

    opts =
      opts ++
        if Keyword.get(opts, :four_cars?) do
          [
            multi_carriage_details:
              make_carriage_details([{"1706", "1"}, {"1707", "1"}, {"1502", "1"}, {"1503", "1"}])
          ]
        else
          []
        end

    %Predictions.Prediction{
      stop_id: Keyword.get(opts, :stop_id, "1"),
      seconds_until_arrival: Keyword.get(opts, :seconds_until_arrival),
      seconds_until_departure: Keyword.get(opts, :seconds_until_departure),
      seconds_until_passthrough: Keyword.get(opts, :seconds_until_passthrough),
      direction_id: Keyword.get(opts, :direction_id, 0),
      schedule_relationship: Keyword.get(opts, :schedule_relationship),
      route_id: Keyword.get(opts, :route_id),
      trip_id: Keyword.get(opts, :trip_id, "123"),
      destination_stop_id: Keyword.get(opts, :destination_stop_id),
      stopped_at_predicted_stop?: Keyword.get(opts, :stopped_at_predicted_stop, false),
      boarding_status: Keyword.get(opts, :boarding_status),
      revenue_trip?: true,
      vehicle_id: "v1",
      multi_carriage_details: Keyword.get(opts, :multi_carriage_details),
      type: Keyword.get(opts, :type, :mid_trip)
    }
  end

  defp location(opts) do
    %Locations.Location{
      route_id: Keyword.get(opts, :route_id, "Red"),
      status:
        case Keyword.get(opts, :crowding_confidence) do
          :low -> :stopped_at
          :high -> :incoming_at
        end,
      stop_id: Keyword.get(opts, :stop_id, "1"),
      multi_carriage_details:
        Keyword.get(
          opts,
          :carriage_details,
          make_carriage_details([
            {"1", "1"},
            {"2", "1"},
            {"3", "99"},
            {"4", "99"},
            {"5", "99"},
            {"6", "99"}
          ])
        )
    }
  end

  defp datetime(time), do: DateTime.new!(~D[2023-01-01], time, "America/New_York")
  defp datetime(date, time), do: DateTime.new!(date, time, "America/New_York")

  defp spaced(list), do: PaEss.Utilities.pad_takes(list)

  defp make_carriage_details(list) do
    Enum.map(list, fn {vehicle_id, occupancy_percentage} ->
      %Locations.CarriageDetails{
        label: vehicle_id,
        occupancy_percentage: occupancy_percentage
      }
    end)
  end
end
