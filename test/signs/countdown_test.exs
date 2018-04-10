defmodule Signs.CountdownTest do
  use ExUnit.Case, async: true

  defmodule FakeUpdater do
    def update_sign({"test-sign", "notify-me"}, _, _, _, _) do
      send self(), {:update_sign, {"test-sign", "notify-me"}}
      {:reply, {:ok, :sent}, []}
    end
    def update_sign(_pa_ess_id, "1", _msg, _duration, _start_secs) do
      {:reply, {:ok, :sent}, []}
    end
    def update_sign(_pa_ess_id, "2", _msg, _duration, _start_secs) do
      {:reply, {:ok, :sent}, []}
    end
  end

  defmodule FakePredictionsEngine do
    def for_stop("many_predictions") do
      [%Predictions.Prediction{
        stop_id: "many_predictions",
        direction_id: 1,
        seconds_until_arrival: 10,
        route_id: "mattapan"
       },
      %Predictions.Prediction{
        stop_id: "many_predictions",
        direction_id: 1,
        seconds_until_arrival: 200,
        route_id: "mattapan"
       }]
    end
    def for_stop(gtfs_stop_id) do
      [%Predictions.Prediction{
        stop_id: gtfs_stop_id,
        direction_id: 1,
        seconds_until_arrival: 10,
        route_id: "mattapan"
       }]
    end
  end

  @sign %Signs.Countdown{
    id: "test-sign",
    pa_ess_id: "123",
    gtfs_stop_id: "321",
    route_id: "Mattapan",
    headsign: "Mattapan",
    current_content_bottom: "Mattapan 1 minute",
    current_content_top: "Mattapan 2 minutes",
    sign_updater: FakeUpdater,
    prediction_engine: FakePredictionsEngine
  }

  describe "update_content callback" do
    test "when top has new predictions, sends an update" do
      top_content = %Content.Message.Predictions{
        headsign: "Mattapan", minutes: :arriving
      }
      assert {:noreply, %{current_content_top: ^top_content, current_content_bottom: %Content.Message.Empty{}}} = Signs.Countdown.handle_info(:update_content, @sign)
    end

    test "when bottom has new predictions, sends an update" do
      sign = %Signs.Countdown{
        id: "test-sign",
        pa_ess_id: "123",
        gtfs_stop_id: "many_predictions",
        route_id: "Mattapan",
        headsign: "Mattapan",
        current_content_bottom: nil,
        current_content_top: nil,
        sign_updater: FakeUpdater,
        prediction_engine: FakePredictionsEngine
      }

      top_content = %Content.Message.Predictions{
        headsign: "Mattapan", minutes: :arriving
      }

      bottom_content = %Content.Message.Predictions{
        headsign: "Mattapan", minutes: 3
      }

      assert {:noreply, %{current_content_top: ^top_content, current_content_bottom: ^bottom_content}} = Signs.Countdown.handle_info(:update_content, sign)
    end

    test "when unchanged, no update sent" do
      sign = %Signs.Countdown{
        id: "test-sign",
        pa_ess_id: "notify-me",
        gtfs_stop_id: "321",
        route_id: "Mattapan",
        headsign: "Mattapan",
        current_content_bottom: nil,
        current_content_top: nil,
        sign_updater: FakeUpdater,
        prediction_engine: FakePredictionsEngine
      }

      assert {:noreply, %Signs.Countdown{}} = Signs.Countdown.handle_info(:update_content, sign)

      assert(receive do
        {:update_sign, {"test-sign", "notify-me"}} -> false
      after
        0 -> true
      end)
    end
  end

  describe "expire_x callback" do

    test "expire_top removes anything in the current_content_top field" do
      {:noreply, sign} = Signs.Countdown.handle_info(:expire_top, @sign)
      assert sign.current_content_top == Content.Message.Empty.new()
    end

    test "expire_bottom removes anything in the current_content_bottom field" do
      {:noreply, sign} = Signs.Countdown.handle_info(:expire_bottom, @sign)
      assert sign.current_content_bottom == Content.Message.Empty.new()
    end
  end
end
