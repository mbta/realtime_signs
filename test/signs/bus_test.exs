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
  end

  defmodule FakeConfig do
    def sign_config("auto_sign"), do: :auto
    def sign_config("off_sign"), do: :off
    def sign_config("static_sign"), do: {:static_text, {"custom", "message"}}
    def chelsea_bridge_config(), do: :auto
  end

  defmodule FakeChelseaBridge do
    def bridge_status(), do: %{raised?: false, estimate: nil}
  end

  defmodule FakeChelseaBridgeRaised do
    def bridge_status(), do: %{raised?: true, estimate: Timex.shift(Timex.now(), minutes: 4)}
  end

  @sign_state %Signs.Bus{
    id: "auto_sign",
    pa_ess_loc: "ABCD",
    text_zone: "m",
    audio_zones: ["m"],
    max_minutes: 60,
    sources: nil,
    top_sources: nil,
    bottom_sources: nil,
    extra_audio_sources: nil,
    chelsea_bridge: nil,
    read_loop_interval: 360,
    read_loop_offset: 30,
    config_engine: FakeConfig,
    prediction_engine: FakeBusPredictions,
    bridge_engine: FakeChelseaBridge,
    sign_updater: PaEss.Updater.Mock,
    prev_predictions: [],
    prev_bridge_status: nil,
    current_messages: {nil, nil},
    last_update: nil,
    last_read_time: Timex.shift(Timex.now(), minutes: -10)
  }

  setup :verify_on_exit!

  describe "run loop" do
    test "platform mode, top two" do
      expect_messages(["14 WakfldAv  2 min", "14 WakfldAv 11 min"])

      expect_audios([
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
      ])

      state =
        Map.merge(@sign_state, %{
          sources: [
            %{
              stop_id: "stop1",
              routes: [%{route_id: "14", direction_id: 0}]
            }
          ]
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "platform mode, multiple pages" do
      expect_messages([
        [{"14 WakefldAv 2 min", 6}, {"Chelsea      4 min", 6}],
        [{"34 Clarendon 7 min", 6}, {"", 6}]
      ])

      expect_audios([
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
            "678",
            "605",
            "5507",
            "505",
            "21012",
            "860",
            "5504",
            "505"
          ], :audio}}
      ])

      state =
        Map.merge(@sign_state, %{
          sources: [
            %{
              stop_id: "stop1",
              routes: [
                %{route_id: "14", direction_id: 0},
                %{route_id: "34", direction_id: 1},
                %{route_id: "741", direction_id: 1}
              ]
            }
          ]
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "mezzanine mode" do
      expect_messages(["SL5 Nubian   8 min", "14 WakefldAv 2 min"])

      expect_audios([
        {:canned,
         {"113",
          ["548", "21012", "587", "812", "5508", "505", "21012", "575", "621", "5502", "505"],
          :audio}}
      ])

      state =
        Map.merge(@sign_state, %{
          top_sources: [
            %{
              stop_id: "stop2",
              routes: [%{route_id: "749", direction_id: 0}]
            }
          ],
          bottom_sources: [
            %{
              stop_id: "stop1",
              routes: [%{route_id: "14", direction_id: 0}]
            }
          ]
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "static mode" do
      expect_messages(["custom", "message"])
      expect_audios([{:ad_hoc, {"custom message", :audio}}])

      state = Map.merge(@sign_state, %{id: "static_sign"})

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "off mode" do
      expect_messages(["", ""])

      state =
        Map.merge(@sign_state, %{
          id: "off_sign",
          sources: [
            %{
              stop_id: "stop1",
              routes: [%{route_id: "14", direction_id: 0}]
            }
          ]
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "bridge raised" do
      expect_messages([
        [{"14 WakfldAv  2 min", 6}, {"Drawbridge is up", 6}],
        [{"14 WakfldAv 11 min", 6}, {"SL3 delays 4 more min", 6}]
      ])

      expect_audios([
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
      ])

      state =
        Map.merge(@sign_state, %{
          sources: [
            %{
              stop_id: "stop1",
              routes: [%{route_id: "14", direction_id: 0}]
            }
          ],
          chelsea_bridge: "audio_visual",
          bridge_engine: FakeChelseaBridgeRaised
        })

      Signs.Bus.handle_info(:run_loop, state)
    end

    test "standalone bridge announcement" do
      expect_audios([
        {:canned, {"135", ["5504"], :audio_visual}},
        {:canned, {"152", ["37004"], :audio_visual}}
      ])

      state =
        Map.merge(@sign_state, %{
          sources: [
            %{
              stop_id: "stop1",
              routes: [%{route_id: "14", direction_id: 0}]
            }
          ],
          chelsea_bridge: "audio",
          bridge_engine: FakeChelseaBridgeRaised,
          prev_bridge_status: %{raised?: false, estimate: nil},
          current_messages: {
            %Content.Message.BusPredictions{message: "14 WakfldAv  2 min"},
            %Content.Message.BusPredictions{message: "14 WakfldAv 11 min"}
          },
          last_update: Timex.shift(Timex.now(), seconds: -40),
          last_read_time: Timex.now()
        })

      Signs.Bus.handle_info(:run_loop, state)
    end
  end

  defp expect_messages(messages) do
    expect(PaEss.Updater.Mock, :update_sign, fn {"ABCD", "m"}, top, bottom, 180, :now ->
      assert [Content.Message.to_string(top), Content.Message.to_string(bottom)] == messages
      :ok
    end)
  end

  defp expect_audios(audios) do
    expect(PaEss.Updater.Mock, :send_audio, fn {"ABCD", ["m"]}, list, 5, 180 ->
      assert Enum.map(list, &Content.Audio.to_params(&1)) == audios
      :ok
    end)
  end
end
