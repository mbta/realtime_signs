defmodule  Signs.SingleTest do
  use ExUnit.Case

  defmodule FakeUpdater do
    def update_sign(_pa_ess_id, _, _msg, _duration, _start_secs) do
      {:reply, {:ok, :sent}, []}
    end
  end

  defmodule FakePredictionsEngine do
    def for_stop("ashmont-stop", 1) do
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
    def for_stop(gtfs_stop_id, 1) do
      [%Predictions.Prediction{
        stop_id: gtfs_stop_id,
        direction_id: 1,
        seconds_until_arrival: 10,
        route_id: "mattapan"
       }]
    end
  end

  @sign %Signs.Single{
    id: "Ashmont",
    pa_ess_id: "Ashmont",
    line_number: "2",
    gtfs_stop_id: "ashmont-stop",
    direction_id: 1,
    route_id: "Mattapan",
    headsign: "Mattapan",
    current_content: "Mattapan 1 minute",
    sign_updater: FakeUpdater,
    prediction_engine: FakePredictionsEngine
  }

  describe "update_content callback" do
    test "when content has new predictions, sends an update" do
      content = %Content.Message.Predictions{headsign: "Mattapan", minutes: :arriving}
      assert {:noreply, %{current_content: ^content}} = Signs.Single.handle_info(:update_content, @sign)
    end
  end
end
