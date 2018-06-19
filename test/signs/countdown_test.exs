defmodule Signs.CountdownTest do
  use ExUnit.Case, async: true

  defmodule FakeUpdater do
    def update_single_line({"test-sign", "notify-me"}, _, _, _, _) do
      pid = case Process.whereis(:fake_updater_listener) do
        nil -> self()
        registered -> registered
      end

      send pid, {:update_single_line, {"test-sign", "notify-me"}}
      {:reply, {:ok, :sent}, []}
    end
    def update_single_line(_pa_ess_id, "1", _msg, _duration, _start_secs) do
      {:reply, {:ok, :sent}, []}
    end
    def update_single_line(_pa_ess_id, "2", _msg, _duration, _start_secs) do
      {:reply, {:ok, :sent}, []}
    end
    def update_sign("notsent", _, _, _duration, _start) do
      {:error, :notsent}
    end
    def update_sign(_pa_ess_id, _top, _bottom, _duration, _start) do
      {:ok, :sent}
    end
    def send_audio(pa_ess_id, msg, priority, timeout) do
      pid = case Process.whereis(:fake_updater_listener) do
        nil -> self()
        registered -> registered
      end

      send pid, {:send_audio, {pa_ess_id, msg, priority, timeout}}
      {:reply, {:ok, :sent}, []}
    end
  end

  defmodule FakePredictionsEngine do
    def for_stop("many_predictions", 1) do
      [%Predictions.Prediction{
        stop_id: "many_predictions",
        direction_id: 1,
        seconds_until_arrival: 10,
        route_id: "mattapan"
       },
      %Predictions.Prediction{
        stop_id: "many_predictions",
        direction_id: 1,
        seconds_until_arrival: 500,
        route_id: "mattapan"
       },
      %Predictions.Prediction{
          stop_id: "many_predictions",
          direction_id: 1,
          seconds_until_arrival: 200,
          route_id: "mattapan"
       }]
    end
    def for_stop("not-arriving", 1) do
      [%Predictions.Prediction{
        stop_id: "not-arriving",
        direction_id: 1,
        seconds_until_arrival: 100,
        route_id: "mattapan"
       }]
    end
    def for_stop(gtfs_stop_id, 1) do
      [%Predictions.Prediction{
        stop_id: gtfs_stop_id,
        direction_id: 1,
        seconds_until_arrival: 10,
        route_id: "mattapan"
       }]
    end
  end

  @content_sign %Signs.Countdown{
    id: "test-sign",
    pa_ess_id: "123",
    gtfs_stop_id: "321",
    direction_id: 1,
    route_id: "Mattapan",
    headsign: "Mattapan",
    current_content_bottom: "Mattapan 1 minute",
    current_content_top: "Mattapan 2 minutes",
    countdown_verb: :arrives,
    terminal: false,
    sign_updater: FakeUpdater,
    prediction_engine: FakePredictionsEngine,
    read_sign_period_ms: 10_000,
  }

  @empty_sign %{@content_sign | gtfs_stop_id: "many_predictions", current_content_bottom: nil, current_content_top: nil, terminal: true}

  @audio_sign %Signs.Countdown{
    id: "audio-sign",
    pa_ess_id: {"ABCD", "n"},
    gtfs_stop_id: "321",
    direction_id: 1,
    route_id: "Mattapan",
    headsign: "Mattapan",
    current_content_bottom: nil,
    current_content_top: %Content.Message.Predictions{headsign: "Mattapan", minutes: 1},
    countdown_verb: :arrives,
    terminal: false,
    sign_updater: FakeUpdater,
    prediction_engine: FakePredictionsEngine,
    read_sign_period_ms: 10_000,
  }

  describe "update_content callback" do
    test "when the sign is a terminal, shows 1 min instead of arriving message" do

      top_content = %Content.Message.Predictions{
        headsign: "Mattapan", minutes: 1
      }

      bottom_content = %Content.Message.Predictions{
        headsign: "Mattapan", minutes: 3
      }

      assert {:noreply, %{current_content_top: ^top_content, current_content_bottom: ^bottom_content}} = Signs.Countdown.handle_info(:update_content, @empty_sign)
    end

    test "Does not update sign when pa_ess updater returns an error" do
      sign = %{@empty_sign | pa_ess_id: "notsent"}

      assert {:noreply, %{current_content_top: nil, current_content_bottom: nil}} = Signs.Countdown.handle_info(:update_content, sign)
    end

    test "when both lines change, sends an update containing both lines" do
      sign = %{@empty_sign | terminal: false}

      top_content = %Content.Message.Predictions{
        headsign: "Mattapan", minutes: :arriving
      }

      bottom_content = %Content.Message.Predictions{
        headsign: "Mattapan", minutes: 3
      }

      assert {:noreply, %{current_content_top: ^top_content, current_content_bottom: ^bottom_content}} = Signs.Countdown.handle_info(:update_content, sign)
    end

    test "when top has new predictions, sends an update" do
      top_content = %Content.Message.Predictions{
        headsign: "Mattapan", minutes: :arriving
      }
      assert {:noreply, %{current_content_top: ^top_content, current_content_bottom: %Content.Message.Empty{}}} = Signs.Countdown.handle_info(:update_content, @content_sign)
    end

    test "when the sign is disabled, does not send an update" do
      sign = %{@content_sign | id: "MVAL0"}
      :timer.sleep(1000)
      assert {:noreply, %{
        current_content_top: %Content.Message.Empty{},
        current_content_bottom: %Content.Message.Empty{}}} = Signs.Countdown.handle_info(:update_content, sign)
    end

    test "when bottom has new predictions, sends an update" do
      sign = %{@empty_sign | terminal: false}

      top_content = %Content.Message.Predictions{
        headsign: "Mattapan", minutes: :arriving
      }

      bottom_content = %Content.Message.Predictions{
        headsign: "Mattapan", minutes: 3
      }

      assert {:noreply, %{current_content_top: ^top_content, current_content_bottom: ^bottom_content}} = Signs.Countdown.handle_info(:update_content, sign)
    end

    test "when unchanged, no update sent" do
      sign = %{@empty_sign | pa_ess_id: "notify-me", terminal: false}

      assert {:noreply, %Signs.Countdown{}} = Signs.Countdown.handle_info(:update_content, sign)

      assert(receive do
        {:update_single_line, {"test-sign", "notify-me"}} -> false
      after
        0 -> true
      end)
    end

    test "when top changes to mattapan arriving, sends an audio message" do

      assert {:noreply, %Signs.Countdown{}} = Signs.Countdown.handle_info(:update_content, @audio_sign)
      assert(receive do
        {:send_audio, {{"ABCD", "n"}, %Content.Audio.TrainIsArriving{destination: :mattapan}, 5, 60}} -> true
      after
        0 -> false
      end)
    end

    test "Does not send arriving audio message if sign is configured to not arriving announcements" do
      sign = %{@audio_sign | announce_arriving?: false}
      assert {:noreply, %Signs.Countdown{}} = Signs.Countdown.handle_info(:update_content, sign)
      refute(receive do
        {:send_audio, {{"ABCD", "n"}, %Content.Audio.TrainIsArriving{destination: :mattapan}, 5, 60}} -> true
      after
        0 -> false
      end)
    end

    test "when top changes to a different minute, no audio message sent" do
      sign = %{@audio_sign | current_content_top: %Content.Message.Predictions{headsign: "Mattapan", minutes: 2},
                            gtfs_stop_id: "not-arriving"}

      assert {:noreply, %Signs.Countdown{}} = Signs.Countdown.handle_info(:update_content, sign)
      assert(receive do
        {:send_audio, _} -> false
      after
        0 -> true
      end)
    end
  end

  describe "read_sign callback" do
    test "sends an audio request when the top line is a minutes-away prediction" do
      sign = %{@audio_sign | current_content_top: %Content.Message.Predictions{headsign: "Mattapan", minutes: 2},
                            gtfs_stop_id: "not-arriving"}

      assert {:noreply, %Signs.Countdown{}} = Signs.Countdown.handle_info(:read_sign, sign)
      assert(receive do
        {:send_audio, {{"ABCD", "n"}, %Content.Audio.NextTrainCountdown{destination: :mattapan, verb: :arrives, minutes: 2}, 5, 60}} -> true
      after
        0 -> false
      end)
    end

    test "does not send an audio request for a boarding prediction" do
      sign = %{@audio_sign | current_content_top: %Content.Message.Predictions{headsign: "Mattapan", minutes: :boarding},
                            gtfs_stop_id: "not-arriving"}

      assert {:noreply, %Signs.Countdown{}} = Signs.Countdown.handle_info(:read_sign, sign)
      assert(receive do
        {:send_audio, _} -> false
      after
        0 -> true
      end)

    end

    test "callback is invoked periodically" do
      Process.register(self(), :fake_updater_listener)
      sign = %{@audio_sign | current_content_top: %Content.Message.Predictions{headsign: "Mattapan", minutes: 2},
                            gtfs_stop_id: "not-arriving", read_sign_period_ms: 1_000}

      {:ok, _pid} = GenServer.start_link(Signs.Countdown, sign)

      :timer.sleep(1500)

      assert(receive do
        {:send_audio, {{"ABCD", "n"}, %Content.Audio.NextTrainCountdown{destination: :mattapan, verb: :arrives, minutes: 1}, 5, 60}} -> false
      after
        0 -> true
      end)

      :timer.sleep(1000)

      assert(receive do
        {:send_audio, {{"ABCD", "n"}, %Content.Audio.NextTrainCountdown{destination: :mattapan, verb: :arrives, minutes: 2}, 5, 60}} -> true
      after
        0 -> false
      end)

      :timer.sleep(1000)

      assert(receive do
        {:send_audio, {{"ABCD", "n"}, %Content.Audio.NextTrainCountdown{destination: :mattapan, verb: :arrives, minutes: 2}, 5, 60}} -> true
      after
        0 -> false
      end)

    end
  end

  describe "expire_x callback" do

    test "expire_top removes anything in the current_content_top field" do
      {:noreply, sign} = Signs.Countdown.handle_info(:expire_top, @content_sign)
      assert sign.current_content_top == Content.Message.Empty.new()
    end

    test "expire_bottom removes anything in the current_content_bottom field" do
      {:noreply, sign} = Signs.Countdown.handle_info(:expire_bottom, @content_sign)
      assert sign.current_content_bottom == Content.Message.Empty.new()
    end
  end

  describe "start_link/2" do
    test "initializes state with sign from config" do
      config = %{
        "id" => "sign_1",
        "gtfs_stop_id" => "stop_id",
        "pa_ess_loc" => "SIGN",
        "pa_ess_zone" => "m",
        "direction_id" => 0,
        "route_id" => "Mattapan",
        "headsign" => "Mattapan",
        "terminal" => false,
        "countdown_verb" => "arrives",
        "type" => "countdown"
      }
      opts = [sign_updater: __MODULE__, prediction_engine: __MODULE__]
      {:ok, pid} = Signs.Countdown.start_link(config, opts)
      state = :sys.get_state(pid)
      assert %{id: "sign_1", gtfs_stop_id: "stop_id", pa_ess_id: {"SIGN", "m"}} = state
    end
  end
end
