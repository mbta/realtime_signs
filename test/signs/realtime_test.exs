defmodule Signs.RealtimeTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  import Mox

  alias Content.Message.Headways.Top, as: HT
  alias Content.Message.Headways.Bottom, as: HB

  @headway_config %Engine.Config.Headway{headway_id: "id", range_low: 11, range_high: 13}

  @src %Signs.Utilities.SourceConfig{
    stop_id: "1",
    direction_id: 0,
    platform: nil,
    terminal?: false,
    announce_arriving?: true,
    announce_boarding?: false
  }

  @fake_time DateTime.new!(~D[2023-01-01], ~T[12:00:00], "America/New_York")
  def fake_time_fn, do: @fake_time

  @sign %Signs.Realtime{
    id: "sign_id",
    text_id: {"TEST", "x"},
    audio_id: {"TEST", ["x"]},
    source_config: %{
      sources: [@src],
      headway_group: "headway_group",
      headway_destination: :southbound
    },
    current_content_top: %HT{destination: :southbound, vehicle_type: :train},
    current_content_bottom: %HB{range: {11, 13}},
    prediction_engine: Engine.Predictions.Mock,
    location_engine: Engine.Locations.Mock,
    headway_engine: Engine.ScheduledHeadways.Mock,
    config_engine: Engine.Config.Mock,
    alerts_engine: Engine.Alerts.Mock,
    current_time_fn: &Signs.RealtimeTest.fake_time_fn/0,
    sign_updater: PaEss.Updater.Mock,
    last_update: @fake_time,
    tick_read: 1,
    read_period_seconds: 100
  }

  @mezzanine_sign %{
    @sign
    | source_config: {
        %{sources: [@src], headway_group: "group", headway_destination: :northbound},
        %{sources: [@src], headway_group: "group", headway_destination: :southbound}
      },
      current_content_top: %HT{vehicle_type: :train, routes: []},
      current_content_bottom: %HB{range: {11, 13}}
  }

  @terminal_sign %{
    @sign
    | source_config: %{
        @sign.source_config
        | sources: [
            %{@src | terminal?: true, announce_arriving?: false, announce_boarding?: true}
          ]
      }
  }

  @no_service_audio {:canned, {"107", ["861", "21000", "864", "21000", "863"], :audio}}

  setup :verify_on_exit!

  describe "run loop" do
    setup do
      stub(Engine.Config.Mock, :sign_config, fn _ -> :auto end)
      stub(Engine.Config.Mock, :headway_config, fn _, _ -> @headway_config end)
      stub(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :none end)
      stub(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)
      stub(Engine.ScheduledHeadways.Mock, :display_headways?, fn _, _, _ -> true end)
      stub(Engine.ScheduledHeadways.Mock, :get_first_scheduled_departure, fn _ -> nil end)
      :ok
    end

    test "starts up and logs unknown messages" do
      assert {:ok, pid} = GenServer.start_link(Signs.Realtime, @sign)

      log =
        capture_log([level: :warn], fn ->
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
          prediction(destination: :braintree, seconds_until_passthrough: 30, trip_id: "123"),
          prediction(destination: :braintree, seconds_until_passthrough: 30, trip_id: "124")
        ]
      end)

      expect_audios([{:canned, {"103", ["32118"], :audio_visual}}])
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

      expect_audios([{:canned, {"103", ["32118"], :audio_visual}}])
      expect_audios([{:canned, {"103", ["32114"], :audio_visual}}])

      Signs.Realtime.handle_info(:run_loop, @mezzanine_sign)
    end

    test "announces passthrough audio for 'Southbound' headsign" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :southbound, seconds_until_passthrough: 30)]
      end)

      expect_audios([{:canned, {"103", ["32117"], :audio_visual}}])
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when custom text is present, display it, overriding alerts" do
      expect(Engine.Config.Mock, :sign_config, fn _ -> {:static_text, {"custom", "message"}} end)
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :suspension_closed_station end)
      expect_messages({"custom", "message"})
      expect_audios([{:ad_hoc, {"custom message", :audio}}])

      assert {_, %{announced_custom_text: "custom message"}} =
               Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is disabled, it's empty" do
      expect(Engine.Config.Mock, :sign_config, fn _ -> :off end)
      expect_messages({"", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a transfer station from a shuttle, and there are no predictions it's empty" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :shuttles_transfer_station end)
      expect_messages({"", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a transfer station from a suspension, and there are no predictions it's empty" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :suspension_transfer_station end)
      expect_messages({"", ""})
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a station closed by shuttles and there are no predictions, it says so" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :shuttles_closed_station end)
      expect_messages({"No train service", "Use shuttle bus"})
      expect_audios([{:canned, {"199", ["864"], :audio}}])
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a station closed and there are no predictions, but shuttles do not run at this station" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :shuttles_closed_station end)
      expect_messages({"No train service", ""})
      expect_audios([@no_service_audio])
      Signs.Realtime.handle_info(:run_loop, %{@sign | uses_shuttles: false})
    end

    test "when sign is at a station closed due to suspension and there are no predictions, it says so" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :suspension_closed_station end)
      expect_messages({"No train service", ""})
      expect_audios([@no_service_audio])
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "when sign is at a closed station and there are no predictions, it says so" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :station_closure end)
      expect_messages({"No train service", ""})
      expect_audios([@no_service_audio])
      assert {_, %{announced_alert: true}} = Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "predictions take precedence over alerts" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :suspension_closed_station end)

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

    test "ignores predictions with no departure time" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, seconds_until_departure: nil)]
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
      expect(Engine.Config.Mock, :sign_config, fn _ -> :headway end)

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
      expect(Engine.Config.Mock, :sign_config, fn _ -> :headway end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 120)]
      end)

      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :station_closure end)
      expect_messages({"No train service", ""})
      expect_audios([@no_service_audio])
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
      expect(Engine.Config.Mock, :headway_config, fn _, _ ->
        %{@headway_config | range_high: 14}
      end)

      expect_messages({"Trains", "Every 11 to 14 min"})
      Signs.Realtime.handle_info(:run_loop, @mezzanine_sign)
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

      expect_audios([
        {:canned,
         {"115",
          [
            "501",
            "21000",
            "507",
            "21000",
            "4100",
            "21000",
            "533",
            "21000",
            "641",
            "21000",
            "5008",
            "21000",
            "534"
          ], :audio}}
      ])

      assert {_, %{announced_stalls: [{"1", 8}]}} = Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "When the train is stopped a long time away from a terminal, shows max time instead of stopped" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            destination: :mattapan,
            seconds_until_departure: 2020,
            stopped: 8,
            departure_certainty: 360
          )
        ]
      end)

      expect_messages({"Mattapan   30+ min", ""})
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
          prediction(destination: :mattapan, arrival: 0, stops_away: 0, trip_id: "1"),
          prediction(destination: :mattapan, arrival: 100, stops_away: 1)
        ]
      end)

      expect_messages({"Mattapan       BRD", "Mattapan     2 min"})

      expect_audios([
        {:canned, {"109", ["501", "21000", "507", "21000", "4100", "21000", "544"], :audio}}
      ])

      assert {_, %{announced_boardings: ["1"]}} = Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "Sorts boarding status to the top" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :boston_college, arrival: 200),
          prediction(destination: :cleveland_circle, arrival: 250, stops_away: 0)
        ]
      end)

      expect_messages({"Clvlnd Cir     BRD", "Boston Col   3 min"})

      expect_audios([
        {:canned,
         {"111", ["501", "21000", "537", "21000", "507", "21000", "4203", "21000", "544"], :audio}}
      ])

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "does not allow ARR on second line if platform does not have multiple berths" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :cleveland_circle, arrival: 15, stop_id: "1"),
          prediction(destination: :riverside, arrival: 16, stop_id: "1")
        ]
      end)

      expect_messages({"Clvlnd Cir     ARR", "Riverside    1 min"})
      expect_audios([{:canned, {"103", ["90007"], :audio_visual}}])
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "allows ARR on second line if platform does have multiple berths" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :cleveland_circle, arrival: 15, stop_id: "1", trip_id: "1")]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :riverside, arrival: 16, stop_id: "2", trip_id: "2")]
      end)

      expect_messages({"Clvlnd Cir     ARR", "Riverside      ARR"})

      expect_audios([
        {:canned, {"103", ["90007"], :audio_visual}},
        {:canned, {"103", ["90008"], :audio_visual}}
      ])

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | source_config: %{
            @sign.source_config
            | sources: [
                %{@src | stop_id: "1", multi_berth?: true},
                %{@src | stop_id: "2", multi_berth?: true}
              ]
          }
      })
    end

    test "doesn't sort 0 stops away to first for terminals when another departure is sooner" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :boston_college, seconds_until_departure: 250),
          prediction(destination: :cleveland_circle, seconds_until_departure: 300, stops_away: 0)
        ]
      end)

      expect_messages({"Boston Col   3 min", "Clvlnd Cir   4 min"})
      Signs.Realtime.handle_info(:run_loop, @terminal_sign)
    end

    test "properly handles case where destination can't be determined" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(route_id: "invalid", destination_stop_id: "invalid")]
      end)

      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "Correctly orders BRD predictions between trains mid-trip and those starting their trip" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(
            destination: :riverside,
            stops_away: 0,
            seconds_until_arrival: -30,
            seconds_until_departure: 60,
            trip_id: "1"
          ),
          prediction(
            destination: :riverside,
            stops_away: 0,
            seconds_until_arrival: -15,
            seconds_until_departure: 75,
            trip_id: "2"
          ),
          prediction(
            destination: :boston_college,
            stops_away: 0,
            seconds_until_arrival: nil,
            seconds_until_departure: 60,
            trip_id: "3"
          )
        ]
      end)

      expect_messages({"Riverside      BRD", "Boston Col     BRD"})

      expect_audios([
        {:canned,
         {"111", ["501", "21000", "538", "21000", "507", "21000", "4084", "21000", "544"], :audio}},
        {:canned,
         {"111", ["501", "21000", "536", "21000", "507", "21000", "4202", "21000", "544"], :audio}}
      ])

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

    test "handles passthrough audio where headsign can't be determined" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(seconds_until_passthrough: 30, route_id: "Foo", destination_stop_id: "Bar")]
      end)

      log =
        capture_log([level: :info], fn ->
          Signs.Realtime.handle_info(:run_loop, @sign)
        end)

      assert log =~ "no_passthrough_audio_for_prediction"
    end

    test "reads special boarding button announcement at Bowdoin" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 0, destination: :wonderland, stops_away: 0)]
      end)

      expect_audios([
        {:canned, {"109", ["501", "21000", "507", "21000", "4044", "21000", "544"], :audio}},
        {:canned, {"103", ["869"], :audio_visual}}
      ])

      expect_messages({"Wonderland     BRD", ""})

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | text_id: {"BBOW", "e"},
          source_config: %{@sign.source_config | sources: [%{@src | direction_id: 1}]}
      })
    end

    test "doesn't announce arrivals if disabled in the config" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, arrival: 10)]
      end)

      expect_messages({"Alewife        ARR", ""})

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | source_config: %{@sign.source_config | sources: [%{@src | announce_arriving?: false}]}
      })
    end

    test "doesn't announce arrivals if already announced previously" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, arrival: 10, trip_id: "1")]
      end)

      expect_messages({"Alewife        ARR", ""})
      Signs.Realtime.handle_info(:run_loop, %{@sign | announced_arrivals: ["1"]})
    end

    test "announces approaching" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 45, trip_id: "1")]
      end)

      expect_messages({"Ashmont      1 min", ""})
      expect_audios([{:canned, {"103", ["32127"], :audio_visual}}])
      assert {_, %{announced_approachings: ["1"]}} = Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "doesn't announce approaching if already announced previously" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, arrival: 45, trip_id: "1")]
      end)

      expect_messages({"Alewife      1 min", ""})
      Signs.Realtime.handle_info(:run_loop, %{@sign | announced_approachings: ["1"]})
    end

    test "doesn't announce approaching for light rail" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :cleveland_circle, arrival: 45)]
      end)

      expect_messages({"Clvlnd Cir   1 min", ""})
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
      expect_audios([{:canned, {"90", ["4016", "503", "5002"], :audio}}])
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
      expect_audios([{:canned, {"103", ["32127"], :audio_visual}}])

      assert {_, %{tick_read: 119}} =
               Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 20})
    end

    test "Announce approaching with crowding when condfidence high" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 45, destination: :forest_hills, trip_id: "1")]
      end)

      expect(Engine.Locations.Mock, :for_vehicle, fn _ ->
        location(crowding_description: :front, crowding_confidence: :high)
      end)

      expect_messages({"Frst Hills   1 min", ""})
      expect_audios([{:canned, {"103", ["32123"], :audio_visual}}])

      assert {_, %{announced_approachings_with_crowding: ["1"]}} =
               Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "Announce approaching without crowding when condfidence low" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 45, destination: :forest_hills)]
      end)

      expect(Engine.Locations.Mock, :for_vehicle, fn _ ->
        location(crowding_description: :front, crowding_confidence: :low)
      end)

      expect_messages({"Frst Hills   1 min", ""})
      expect_audios([{:canned, {"103", ["32123"], :audio_visual}}])

      assert {_, %{announced_approachings_with_crowding: []}} =
               Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "Announce arrival with crowding if not already announced" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 15, destination: :forest_hills)]
      end)

      expect(Engine.Locations.Mock, :for_vehicle, fn _ ->
        location(crowding_description: :front, crowding_confidence: :high)
      end)

      expect_messages({"Frst Hills     ARR", ""})
      expect_audios([{:canned, {"103", ["32103"], :audio_visual}}])
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "Don't announce arrival with crowding if confidence low" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 15, destination: :forest_hills)]
      end)

      expect(Engine.Locations.Mock, :for_vehicle, fn _ ->
        location(crowding_description: :front, crowding_confidence: :low)
      end)

      expect_messages({"Frst Hills     ARR", ""})
      expect_audios([{:canned, {"103", ["32103"], :audio_visual}}])
      Signs.Realtime.handle_info(:run_loop, @sign)
    end

    test "Don't announce arrival with crowding if already announced with approaching" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(arrival: 15, destination: :forest_hills, trip_id: "1")]
      end)

      expect(Engine.Locations.Mock, :for_vehicle, fn _ ->
        location(crowding_description: :front, crowding_confidence: :high)
      end)

      expect_messages({"Frst Hills     ARR", ""})
      expect_audios([{:canned, {"103", ["32103"], :audio_visual}}])

      Signs.Realtime.handle_info(:run_loop, %{@sign | announced_approachings_with_crowding: ["1"]})
    end

    test "reads predictions" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 120),
          prediction(destination: :ashmont, arrival: 240)
        ]
      end)

      expect_messages({"Ashmont      2 min", "Ashmont      4 min"})

      expect_audios([
        {:canned, {"90", ["4016", "503", "5002"], :audio}},
        {:canned, {"160", ["4016", "503", "5004"], :audio}}
      ])

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0})
    end

    test "reads headways" do
      expect_audios([{:canned, {"184", ["5511", "5513"], :audio}}])
      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0})
    end

    test "reads headways in spanish, if available" do
      expect_messages({"Chelsea trains", "Every 11 to 13 min"})

      expect_audios([
        {:canned, {"133", ["5511", "5513"], :audio}},
        {:canned, {"150", ["37011", "37013"], :audio}}
      ])

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | tick_read: 0,
          source_config: %{@sign.source_config | headway_destination: :chelsea}
      })
    end

    test "reads mixed predictions and headways" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 130)]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect_messages(
        {"Ashmont      2 min", [{"Southbound  trains every", 6}, {"Southbound  11 to 13 min", 6}]}
      )

      expect_audios([
        {:canned, {"90", ["4016", "503", "5002"], :audio}},
        {:canned, {"184", ["5511", "5513"], :audio}}
      ])

      Signs.Realtime.handle_info(:run_loop, %{@mezzanine_sign | tick_read: 0})
    end

    test "reads custom messages" do
      expect(Engine.Config.Mock, :sign_config, fn _ -> {:static_text, {"custom", "message"}} end)
      expect_messages({"custom", "message"})
      expect_audios([{:ad_hoc, {"custom message", :audio}}])

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | tick_read: 0,
          announced_custom_text: "custom message"
      })
    end

    test "reads alerts" do
      expect(Engine.Alerts.Mock, :max_stop_status, fn _, _ -> :shuttles_closed_station end)
      expect_messages({"No train service", "Use shuttle bus"})
      expect_audios([{:canned, {"199", ["864"], :audio}}])
      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0, announced_alert: true})
    end

    test "reads approaching" do
      # Note: This case doesn't come up during normal operation, because non-terminal signs
      # announce approaching trains, and that announcement delays readouts until after the train
      # has passed. However, for consistency, we should read approaching trains as "1 minute"
      # in all cases.
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 45, trip_id: "1"),
          prediction(destination: :ashmont, arrival: 130)
        ]
      end)

      expect_messages({"Ashmont      1 min", "Ashmont      2 min"})

      expect_audios([
        {:canned, {"103", ["32127"], :audio_visual}},
        {:canned, {"160", ["4016", "503", "5002"], :audio}}
      ])

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0, announced_approachings: ["1"]})
    end

    test "does not read approaching for following trains" do
      # Note: This behavior exists because we didn't have recorded audio to cover this case at the
      # time, but we should fix this so it works the same as other readouts.
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 15, trip_id: "1"),
          prediction(destination: :ashmont, arrival: 45, trip_id: "2")
        ]
      end)

      expect_messages({"Ashmont        ARR", "Ashmont      1 min"})
      expect_audios([{:canned, {"103", ["32107"], :audio_visual}}])

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | tick_read: 0,
          announced_arrivals: ["1"],
          announced_approachings: ["2"]
      })
    end

    test "reads approaching as 1 minute when on the bottom line and a different headsign" do
      # Note: This should be the default behavior for reading approaching trains, rather than a
      # special case.
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 0, stops_away: 0, trip_id: "1"),
          prediction(destination: :braintree, arrival: 45, trip_id: "2")
        ]
      end)

      expect_messages({"Ashmont        BRD", "Braintree    1 min"})

      expect_audios([
        {:canned, {"109", ["501", "21000", "507", "21000", "4016", "21000", "544"], :audio}},
        {:canned, {"141", ["4021", "503"], :audio}}
      ])

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | tick_read: 0,
          announced_arrivals: ["1"],
          announced_approachings: ["2"]
      })
    end

    test "only reads the top line when the top line is arriving and heavy rail" do
      # Note: This case doesn't come up during normal operation, because non-terminal signs
      # announce arriving trains, and that announcement delays readouts until after the train
      # has passed. However, for consistency, we should read the full sign.
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [
          prediction(destination: :ashmont, arrival: 15, trip_id: "1"),
          prediction(destination: :ashmont, arrival: 120)
        ]
      end)

      expect_messages({"Ashmont        ARR", "Ashmont      2 min"})
      expect_audios([{:canned, {"103", ["32107"], :audio_visual}}])
      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0, announced_arrivals: ["1"]})
    end

    test "only reads the bottom line when the bottom line is arriving on a multi_source sign for heavy rail" do
      # Note: This case doesn't come up during normal operation, because non-terminal signs
      # announce arriving trains, and that announcement delays readouts until after the train
      # has passed. However, for consistency, we should read the full sign.
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :ashmont, arrival: 120)]
      end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, arrival: 15, trip_id: "1")]
      end)

      expect_messages({"Ashmont      2 min", "Alewife        ARR"})
      expect_audios([{:canned, {"103", ["32104"], :audio_visual}}])

      Signs.Realtime.handle_info(:run_loop, %{
        @mezzanine_sign
        | tick_read: 0,
          announced_arrivals: ["1"]
      })
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

      expect_audios([
        {:canned,
         {"115",
          [
            "501",
            "21000",
            "507",
            "21000",
            "4016",
            "21000",
            "533",
            "21000",
            "641",
            "21000",
            "5003",
            "21000",
            "534"
          ], :audio}}
      ])

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

      expect_audios([
        {:canned,
         {"115",
          [
            "501",
            "21000",
            "507",
            "21000",
            "4016",
            "21000",
            "533",
            "21000",
            "641",
            "21000",
            "5003",
            "21000",
            "534"
          ], :audio}}
      ])

      Signs.Realtime.handle_info(:run_loop, %{@sign | tick_read: 0, announced_stalls: ["1"]})
    end

    test "JFK mezzanine special case" do
      expect(Engine.Predictions.Mock, :for_stop, fn _, _ -> [] end)

      expect(Engine.Predictions.Mock, :for_stop, fn _, _ ->
        [prediction(destination: :alewife, arrival: 240, stop_id: "70086")]
      end)

      expect_messages(
        {[{"Alewife      4 min", 6}, {"Northbound trains", 6}],
         [{"on Ashmont platform", 6}, {"Every 11 to 13 min", 6}]}
      )

      expect_audios([
        {:canned, {"98", ["4000", "503", "5004", "4016"], :audio}},
        {:canned, {"183", ["5511", "5513"], :audio}}
      ])

      Signs.Realtime.handle_info(:run_loop, %{
        @sign
        | text_id: {"RJFK", "m"},
          source_config: {
            %{sources: [@src], headway_group: "group", headway_destination: :northbound},
            %{
              sources: [%{@src | stop_id: "70086", direction_id: 1, platform: :ashmont}],
              headway_group: "group",
              headway_destination: :southbound
            }
          },
          tick_read: 0
      })
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

  defp expect_messages(messages) do
    expect(PaEss.Updater.Mock, :update_sign, fn {_, _}, top, bottom, 145, :now, _sign_id ->
      assert {Content.Message.to_string(top), Content.Message.to_string(bottom)} == messages
      :ok
    end)
  end

  defp expect_audios(audios) do
    expect(PaEss.Updater.Mock, :send_audio, fn {_, _}, list, 5, 60, _sign_id ->
      assert Enum.map(list, &Content.Audio.to_params(&1)) == audios
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
          nil -> []
          stops -> [stops_away: stops, boarding_status: "Stopped #{stops} stop away"]
        end

    %Predictions.Prediction{
      stop_id: Keyword.get(opts, :stop_id, "1"),
      seconds_until_arrival: Keyword.get(opts, :seconds_until_arrival),
      arrival_certainty: nil,
      seconds_until_departure: Keyword.get(opts, :seconds_until_departure),
      departure_certainty: Keyword.get(opts, :departure_certainty),
      seconds_until_passthrough: Keyword.get(opts, :seconds_until_passthrough),
      direction_id: Keyword.get(opts, :direction_id, 0),
      schedule_relationship: nil,
      route_id: Keyword.get(opts, :route_id),
      trip_id: Keyword.get(opts, :trip_id, "123"),
      destination_stop_id: Keyword.get(opts, :destination_stop_id),
      stopped?: false,
      stops_away: Keyword.get(opts, :stops_away, 1),
      boarding_status: Keyword.get(opts, :boarding_status),
      new_cars?: false,
      revenue_trip?: true,
      vehicle_id: "v1"
    }
  end

  defp location(opts) do
    %Locations.Location{
      status:
        case Keyword.get(opts, :crowding_confidence) do
          :low -> :stopped_at
          :high -> :incoming_at
        end,
      stop_id: Keyword.get(opts, :stop_id, "1"),
      multi_carriage_details:
        case Keyword.get(opts, :crowding_description) do
          :front ->
            [
              :many_seats_available,
              :many_seats_available,
              :standing_room_only,
              :standing_room_only,
              :standing_room_only,
              :standing_room_only
            ]
        end
        |> Enum.map(&%Locations.CarriageDetails{occupancy_status: &1})
    }
  end
end
