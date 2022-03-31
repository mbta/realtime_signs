defmodule Fake.MessageQueue do
  def get_message do
    {:update_single_line, [{"SBOX", "c"}, "1", %Content.Message.Empty{}, 60, :now]}
  end
end

defmodule PaEss.HttpUpdaterTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  defmodule FakePoster do
    def post(_, q, _, _) do
      send(self(), {:post, q})
      {:ok, %HTTPoison.Response{status_code: 200}}
    end
  end

  describe "process/2" do
    test "replys with {:ok, :sent} when successful" do
      state = make_state()

      log =
        capture_log(fn ->
          assert PaEss.HttpUpdater.process(
                   {:update_single_line,
                    [{"SBOX", "c"}, "1", %Content.Message.Empty{}, 60, :now]},
                   state
                 ) == {:ok, :sent}
        end)

      assert log =~ ~r" arinc_ms=\d+"
      assert log =~ ~r" signs_ui_ms=\d+"
    end

    test "Posts a request to display a message now" do
      state = make_state()
      msg = %Content.Message.Predictions{destination: :wonderland, minutes: :boarding}

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process(
                 {:update_single_line, [{"ABCD", "n"}, 1, msg, 60, :now]},
                 state
               )
    end

    test "Returns an error if HTTP response code is not 2XX" do
      state = make_state()
      msg = %Content.Message.Predictions{destination: :wonderland, minutes: :arriving}

      assert {:error, :bad_status} ==
               PaEss.HttpUpdater.process(
                 {:update_single_line, [{"bad_sign", "n"}, 1, msg, 60, 1234]},
                 state
               )
    end

    test "Returns error if HTTP request fails, doesn't send to Signs UI" do
      state = make_state()
      msg = %Content.Message.Predictions{destination: :wonderland, minutes: 2}

      log =
        capture_log([level: :info], fn ->
          assert {:error, :post_error} ==
                   PaEss.HttpUpdater.process(
                     {:update_single_line, [{"timeout", "n"}, 1, msg, 60, 1234]},
                     state
                   )
        end)

      assert log =~ ~r" arinc_ms=\d+"
      refute log =~ ~r" signs_ui_ms=\d+"
    end

    test "Posts both lines of the sign at the same time" do
      state = make_state()
      top = %Content.Message.Predictions{destination: :wonderland, minutes: :boarding}
      bottom = %Content.Message.Predictions{destination: :wonderland, minutes: 2}

      log =
        capture_log(fn ->
          assert {:ok, :sent} ==
                   PaEss.HttpUpdater.process(
                     {:update_sign, [{"ABCD", "n"}, top, bottom, 60, :now]},
                     state
                   )
        end)

      assert log =~ ~r" arinc_ms=\d+"
      assert log =~ ~r" signs_ui_ms=\d+"
    end

    test "Returns error if HTTP request fails when updating both lines, doesn't send to Signs UI" do
      state = make_state()
      top = %Content.Message.Predictions{destination: :wonderland, minutes: :boarding}
      bottom = %Content.Message.Predictions{destination: :wonderland, minutes: 2}

      log =
        capture_log([level: :info], fn ->
          assert {:error, :post_error} ==
                   PaEss.HttpUpdater.process(
                     {:update_sign, [{"timeout", "n"}, top, bottom, 60, :now]},
                     state
                   )
        end)

      assert log =~ ~r" arinc_ms=\d+"
      refute log =~ ~r" signs_ui_ms=\d+"
    end

    test "replies with {:ok, :sent} when successful" do
      state = make_state()

      assert PaEss.HttpUpdater.process(
               {:update_sign,
                [{"SBOX", "c"}, %Content.Message.Empty{}, %Content.Message.Empty{}, 60, :now]},
               state
             ) == {:ok, :sent}
    end

    test "replies with {:ok, :no_audio} when to_params returns nil" do
      state = make_state()

      audio = %Fake.UnknownAudio{}

      assert {:ok, :no_audio} ==
               PaEss.HttpUpdater.process({:send_audio, [{"GKEN", ["m"]}, audio, 5, 60]}, state)
    end
  end

  describe "send_audio/4" do
    test "Buses to Chelsea" do
      state = make_state()

      audio = %Content.Audio.VehiclesToDestination{
        language: :english,
        destination: :chelsea,
        headway_range: {8, 12}
      }

      log =
        capture_log(fn ->
          assert {:ok, :sent} ==
                   PaEss.HttpUpdater.process(
                     {:send_audio, [{"SBOX", ["c"]}, audio, 5, 60]},
                     state
                   )
        end)

      assert log =~ ~r"arinc_ms=\d+"
    end

    test "Buses to South Station" do
      state = make_state()

      audio = %Content.Audio.VehiclesToDestination{
        language: :english,
        destination: :south_station,
        headway_range: {8, 12}
      }

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process({:send_audio, [{"SBSQ", ["m"]}, audio, 5, 60]}, state)
    end

    test "Buses to Chelsea, in Spanish" do
      state = make_state()

      audio = %Content.Audio.VehiclesToDestination{
        language: :spanish,
        destination: :chelsea,
        headway_range: {8, 14}
      }

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process({:send_audio, [{"SBOX", ["e"]}, audio, 5, 60]}, state)
    end

    test "Next train to Ashmont arrives in 4 minutes" do
      state = make_state()

      audio = %Content.Audio.NextTrainCountdown{
        destination: :ashmont,
        route_id: "Mattapan",
        verb: :arrives,
        track_number: nil,
        minutes: 4
      }

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process({:send_audio, [{"MCED", ["n"]}, audio, 5, 60]}, state)
    end

    test "Train to Mattapan arriving" do
      state = make_state()

      audio = %Content.Audio.TrainIsArriving{
        destination: :mattapan
      }

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process({:send_audio, [{"MCED", ["s"]}, audio, 5, 60]}, state)
    end

    test "Train to Ashmont arriving" do
      state = make_state()

      audio = %Content.Audio.TrainIsArriving{
        destination: :ashmont,
        route_id: "Mattapan"
      }

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process({:send_audio, [{"MCAP", ["n"]}, audio, 5, 60]}, state)
    end

    test "sends custom audio messages" do
      state = make_state()

      audio = %Content.Audio.Custom{
        message: "Custom Message"
      }

      log =
        capture_log(fn ->
          assert {:ok, :sent} ==
                   PaEss.HttpUpdater.process(
                     {:send_audio, [{"MCAP", ["n"]}, audio, 5, 60]},
                     state
                   )
        end)

      assert log =~ ~r" arinc_ms=\d+"
      assert log =~ "send_custom_audio"
    end

    test "sends custom audio messages with replacements" do
      state = make_state()

      audio = %Content.Audio.Custom{
        message: "Custom OL Message"
      }

      log =
        capture_log(fn ->
          assert {:ok, :sent} =
                   PaEss.HttpUpdater.process(
                     {:send_audio, [{"MCAP", ["n"]}, audio, 5, 60]},
                     state
                   )
        end)

      assert log =~ "send_custom_audio"
      assert log =~ "Custom+Orange+Line+Message"
    end

    test "can send two audio messages" do
      state = make_state(%{http_poster: FakePoster})

      audio1 = %Content.Audio.NextTrainCountdown{
        destination: :ashmont,
        route_id: "Red",
        verb: :arrives,
        track_number: nil,
        minutes: 2
      }

      audio2 = %Content.Audio.NextTrainCountdown{
        destination: :braintree,
        route_id: "Red",
        verb: :arrives,
        track_number: nil,
        minutes: 7
      }

      PaEss.HttpUpdater.process({:send_audio, [{"RPRK", ["s"]}, {audio1, audio2}, 5, 60]}, state)

      assert_received {:post, q1}
      assert_received {:post, q2}
      assert q1 =~ "var=4016"
      assert q2 =~ "var=4021"
    end
  end

  test "can send to multiple zones at once" do
    state = make_state(%{http_poster: FakePoster})

    audio = %Content.Audio.NextTrainCountdown{
      destination: :ashmont,
      route_id: "Red",
      verb: :arrives,
      track_number: nil,
      minutes: 2
    }

    PaEss.HttpUpdater.process({:send_audio, [{"RPRK", ["m", "s", "c"]}, audio, 5, 60]}, state)
    assert_received {:post, q}
    assert q =~ "sta=RPRK110100"
  end

  test "handle_info pulls from queue" do
    state = make_state(%{queue_mod: Fake.MessageQueue})
    {response, _} = PaEss.HttpUpdater.handle_info(:check_queue, state)

    assert response == :noreply
  end

  describe "to_command/5" do
    test "handles messages that are single string" do
      msg = %Content.Message.Predictions{destination: :wonderland, minutes: 2}

      assert PaEss.HttpUpdater.to_command(msg, 55, :now, "n", 1) ==
               "e55~n1-\"Wonderland   2 min\""
    end

    test "handles messages that paginate" do
      msg = %Content.Message.StoppedTrain{destination: :ashmont, stops_away: 3}

      assert PaEss.HttpUpdater.to_command(msg, 55, :now, "n", 1) ==
               "e55~n1-\"Ashmont       away\".2-\"Ashmont    Stopped\".5-\"Ashmont    3 stops\".2"
    end
  end

  defp make_state(init \\ %{}) do
    Map.merge(
      %{
        http_poster: Fake.HTTPoison,
        updater_index: 1,
        internal_counter: 0,
        timestamp: div(System.system_time(:millisecond), 500)
      },
      init
    )
  end
end
