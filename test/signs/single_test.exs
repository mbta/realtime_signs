defmodule  Signs.SingleTest do
  use ExUnit.Case, async: true

  defmodule FakeUpdater do
    def update_single_line(_pa_ess_id, _, _msg, _duration, _start_secs) do
      {:reply, {:ok, :sent}, []}
    end

    def send_audio(pa_ess_id, msg, priority, timeout) do
      if Process.whereis(:single_test_fake_updater_listener) do
        send :single_test_fake_updater_listener, {:send_audio, {pa_ess_id, msg, priority, timeout}}
      end

      {:reply, {:ok, :sent}, []}
    end
  end

  defmodule FakePredictionsEngine do
    def for_stop("ashmont-stop", 1) do
      [%Predictions.Prediction{
        stop_id: "many_predictions",
        direction_id: 1,
        seconds_until_arrival: 10,
        route_id: "mattapan",
        headsign: "Mattapan"
       },
      %Predictions.Prediction{
        stop_id: "many_predictions",
        direction_id: 1,
        seconds_until_arrival: 500,
        route_id: "mattapan",
        headsign: "Mattapan"
       },
      %Predictions.Prediction{
          stop_id: "many_predictions",
          direction_id: 1,
          seconds_until_arrival: 200,
          route_id: "mattapan",
          headsign: "Mattapan"
       }]
    end
    def for_stop("audio-arriving", 1) do
      [%Predictions.Prediction{
        stop_id: "audio-arriving",
        direction_id: 1,
        seconds_until_arrival: 10,
        route_id: "mattapan",
        headsign: "Mattapan"
      }]
    end
    def for_stop("boarding", 1) do
      [%Predictions.Prediction{
        stop_id: "boarding",
        direction_id: 1,
        seconds_until_arrival: 65,
        route_id: "mattapan",
        headsign: "Mattapan"
      }]
    end
    def for_stop("three-mins", 1) do
      [%Predictions.Prediction{
        stop_id: "three-mins",
        direction_id: 1,
        seconds_until_arrival: 190,
        route_id: "mattapan",
        headsign: "Mattapan"
      }]
    end
    def for_stop(gtfs_stop_id, 1) do
      [%Predictions.Prediction{
        stop_id: gtfs_stop_id,
        direction_id: 1,
        seconds_until_arrival: 10,
        route_id: "mattapan",
        headsign: "Mattapan"
       }]
    end
  end

  @sign %Signs.Single{
    id: "Ashmont",
    pa_ess_id: {"RASH", "n"},
    line_number: "2",
    gtfs_stop_id: "ashmont-stop",
    direction_id: 1,
    route_id: "Mattapan",
    current_content: "Mattapan 1 minute",
    sign_updater: FakeUpdater,
    prediction_engine: FakePredictionsEngine,
    read_sign_period_ms: 30_000,
    countdown_verb: :departs,
    announce_arriving?: true,
  }

  describe "update_content callback" do
    test "when the sign is disabled, does not send an update" do
      sign = %{@sign | id: "MVAL0"}
      :timer.sleep(1000)
      assert {:noreply, %{current_content: %Content.Message.Empty{}}} = Signs.Single.handle_info(:update_content, sign)
    end

    test "when content has new predictions, sends an update" do
      content = %Content.Message.Predictions{headsign: "Mattapan", minutes: :arriving}
      assert {:noreply, %{current_content: ^content}} = Signs.Single.handle_info(:update_content, @sign)
    end

    test "when content changes to arriving, sends an audio message" do
      Process.register(self(), :single_test_fake_updater_listener)
      sign = %{@sign | gtfs_stop_id: "audio-arriving"}
      assert {:noreply, %Signs.Single{}} = Signs.Single.handle_info(:update_content, sign)
      assert_received {:send_audio, {{"RASH", "n"}, %Content.Audio.TrainIsArriving{destination: :mattapan}, 5, 60}}
    end

    test "Does not send arriving audio message if sign is configured to not arriving announcements" do
      Process.register(self(), :single_test_fake_updater_listener)
      sign = %{@sign | gtfs_stop_id: "audio-arriving", announce_arriving?: false}
      assert {:noreply, %Signs.Single{}} = Signs.Single.handle_info(:update_content, sign)
      refute_received {:send_audio, {{"RASH", "n"}, %Content.Audio.TrainIsArriving{destination: :mattapan}, 5, 60}}
    end
  end

  describe "read sign callback" do
    test "sends an audio request when the top line is a minutes-away prediction" do
      Process.register(self(), :single_test_fake_updater_listener)
      sign = %{@sign | current_content: %Content.Message.Predictions{headsign: "Mattapan", minutes: 2}}
      assert {:noreply, %Signs.Single{}} = Signs.Single.handle_info(:read_sign, sign)
      assert_received({:send_audio, {{"RASH", "n"}, %Content.Audio.NextTrainCountdown{destination: :mattapan, verb: :departs, minutes: 2}, 5, 60}})
    end

    test "does not send an audio request for a boarding prediction" do
      Process.register(self(), :single_test_fake_updater_listener)
      sign = %{@sign | gtfs_stop_id: "boarding"}
      assert {:noreply, %Signs.Single{}} = Signs.Single.handle_info(:read_sign, sign)
      refute_received({:send_audio, _})
    end

    test "callback is invoked periodically" do
      Process.register(self(), :single_test_fake_updater_listener)
      sign = %{@sign |
        gtfs_stop_id: "three-mins",
        read_sign_period_ms: 1_000,
      }
      {:ok, _pid} = GenServer.start_link(Signs.Single, sign)

      expected_message = {:send_audio, {{"RASH", "n"}, %Content.Audio.NextTrainCountdown{destination: :mattapan, verb: :departs, minutes: 3}, 5, 60}}

      :timer.sleep(500)
      refute_received(^expected_message)
      :timer.sleep(1000)
      assert_received(^expected_message)
      :timer.sleep(10)
      refute_received(^expected_message)
      :timer.sleep(1000)
      assert_received(^expected_message)
    end
  end
end
