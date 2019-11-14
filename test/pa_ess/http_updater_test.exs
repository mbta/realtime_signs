defmodule Fake.MessageQueue do
  def get_message do
    {:update_single_line, [{"SBOX", "c"}, "1", %Content.Message.Empty{}, 60, :now]}
  end
end

defmodule PaEss.HttpUpdaterTest do
  use ExUnit.Case, async: true

  defmodule FakePoster do
    def post(_, q, _) do
      send(self(), {:post, q})
      {:ok, %HTTPoison.Response{status_code: 200}}
    end
  end

  describe "process/2" do
    test "replys with {:ok, :sent} when successful" do
      state = make_state()

      assert PaEss.HttpUpdater.process(
               {:update_single_line, [{"SBOX", "c"}, "1", %Content.Message.Empty{}, 60, :now]},
               state
             ) == {:ok, :sent}
    end

    test "Posts a request to display a message now" do
      state = make_state()
      msg = %Content.Message.Predictions{headsign: "Inf n Beynd", minutes: :boarding}

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process(
                 {:update_single_line, [{"ABCD", "n"}, 1, msg, 60, :now]},
                 state
               )
    end

    test "Returns an error if HTTP response code is not 2XX" do
      state = make_state()
      msg = %Content.Message.Predictions{headsign: "Inf n Beynd", minutes: :arriving}

      assert {:error, :bad_status} ==
               PaEss.HttpUpdater.process(
                 {:update_single_line, [{"bad_sign", "n"}, 1, msg, 60, 1234]},
                 state
               )
    end

    test "Returns an error if HTTP request fails" do
      state = make_state()
      msg = %Content.Message.Predictions{headsign: "Inf n Beynd", minutes: 2}

      assert {:error, :post_error} ==
               PaEss.HttpUpdater.process(
                 {:update_single_line, [{"timeout", "n"}, 1, msg, 60, 1234]},
                 state
               )
    end

    test "Posts both lines of the sign at the same time" do
      state = make_state()
      top = %Content.Message.Predictions{headsign: "Inf n Beynd", minutes: :boarding}
      bottom = %Content.Message.Predictions{headsign: "Inf n Beynd", minutes: 2}

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process(
                 {:update_sign, [{"ABCD", "n"}, top, bottom, 60, :now]},
                 state
               )
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
      state = make_state(%{uid: 1000})

      audio = %Content.Audio.VehiclesToDestination{
        language: :english,
        destination: :chelsea,
        next_trip_mins: 8,
        later_trip_mins: 12
      }

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process({:send_audio, [{"SBOX", ["c"]}, audio, 5, 60]}, state)
    end

    test "Buses to South Station" do
      state = make_state(%{uid: 1001})

      audio = %Content.Audio.VehiclesToDestination{
        language: :english,
        destination: :south_station,
        next_trip_mins: 8,
        later_trip_mins: 12
      }

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process({:send_audio, [{"SBSQ", ["m"]}, audio, 5, 60]}, state)
    end

    test "Chelsea bridge raised, expect delays" do
      state = make_state(%{uid: 1002})

      audio = %Content.Audio.BridgeIsUp{
        language: :english,
        time_estimate_mins: 10
      }

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process({:send_audio, [{"SCHS", ["w"]}, audio, 5, 200]}, state)
    end

    test "Buses to Chelsea, in Spanish" do
      state = make_state(%{uid: 1003})

      audio = %Content.Audio.VehiclesToDestination{
        language: :spanish,
        destination: :chelsea,
        next_trip_mins: 8,
        later_trip_mins: 14
      }

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process({:send_audio, [{"SBOX", ["e"]}, audio, 5, 60]}, state)
    end

    test "Next train to Ashmont arrives in 4 minutes" do
      state = make_state(%{uid: 1004})

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
      state = make_state(%{uid: 1005})

      audio = %Content.Audio.TrainIsArriving{
        destination: :mattapan
      }

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process({:send_audio, [{"MCED", ["s"]}, audio, 5, 60]}, state)
    end

    test "Train to Ashmont arriving" do
      state = make_state(%{uid: 1006})

      audio = %Content.Audio.TrainIsArriving{
        destination: :ashmont,
        route_id: "Mattapan"
      }

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process({:send_audio, [{"MCAP", ["n"]}, audio, 5, 60]}, state)
    end

    test "sends custom audio messages" do
      state = make_state(%{uid: 1006})

      audio = %Content.Audio.Custom{
        message: "Custom Message"
      }

      assert {:ok, :sent} ==
               PaEss.HttpUpdater.process(
                 {:send_audio, [{"MCAP", ["n"]}, audio, 5, 60]},
                 state
               )
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
    assert PaEss.HttpUpdater.handle_info(:check_queue, state) == {:noreply, %{state | uid: 1}}
  end

  describe "to_command/5" do
    test "handles messages that are single string" do
      msg = %Content.Message.Predictions{headsign: "Inf n Beynd", minutes: 2}

      assert PaEss.HttpUpdater.to_command(msg, 55, :now, "n", 1) ==
               "e55~n1-\"Inf n Beynd  2 min\""
    end

    test "handles messages that paginate" do
      msg = %Content.Message.StoppedTrain{headsign: "Ashmont", stops_away: 3}

      assert PaEss.HttpUpdater.to_command(msg, 55, :now, "n", 1) ==
               "e55~n1-\"Ashmont       away\".2-\"Ashmont    Stopped\".5-\"Ashmont    3 stops\".2"
    end
  end

  defp make_state(init \\ %{}) do
    Map.merge(%{http_poster: Fake.HTTPoison, uid: 0}, init)
  end
end
