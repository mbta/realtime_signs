defmodule Engine.PredictionsTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import Engine.Predictions

  describe "handle_info/2" do
    test "keeps existing states when trip_update url has not been modified" do
      trip_update_url = Application.get_env(:realtime_signs, :trip_update_url)
      position_url = Application.get_env(:realtime_signs, :vehicle_position_url)
      Application.put_env(:realtime_signs, :trip_update_url, "trip_updates_304")
      Application.put_env(:realtime_signs, :vehicle_positions_url, "vehicle_positions_304")
      existing_state = {~N[2017-07-04 09:05:00], ~N[2017-07-04 09:05:00]}
      {:noreply, updated_state} = handle_info(:update, existing_state)
      Application.put_env(:realtime_signs, :trip_update_url, trip_update_url)
      Application.put_env(:realtime_signs, :vehicle_position_url, position_url)
      assert updated_state == existing_state
    end

    test "updates vehicle positions in table" do
      trip_update_url = Application.get_env(:realtime_signs, :trip_update_url)
      position_url = Application.get_env(:realtime_signs, :vehicle_position_url)
      Application.put_env(:realtime_signs, :trip_update_url, "trip_updates_304")
      Application.put_env(:realtime_signs, :vehicle_positions_url, "vehicle_positions_url")
      existing_state = {~N[2017-07-04 09:05:00], ~N[2017-07-04 09:05:00]}
      {:noreply, updated_state} = handle_info(:update, existing_state)
      Application.put_env(:realtime_signs, :trip_update_url, trip_update_url)
      Application.put_env(:realtime_signs, :vehicle_position_url, position_url)
      assert updated_state == existing_state
    end

    test "logs error when invalid HTTP response returned" do
      trip_update_url = Application.get_env(:realtime_signs, :trip_update_url)
      position_url = Application.get_env(:realtime_signs, :vehicle_position_url)
      Application.put_env(:realtime_signs, :trip_update_url, "trip_updates_error")
      Application.put_env(:realtime_signs, :vehicle_positions_url, "vehicle_positions_304")
      existing_state = {~N[2017-07-04 09:05:00], ~N[2017-07-04 09:05:00]}
      log = capture_log [level: :warn], fn ->
        {:noreply, last_modified} = handle_info(:update, existing_state)
        assert existing_state == last_modified
      end
      Application.put_env(:realtime_signs, :trip_update_url, trip_update_url)
      Application.put_env(:realtime_signs, :vehicle_position_url, position_url)
      assert log =~ "Could not fetch pb file "
      assert log =~ "timeout"
    end
  end

  describe "for_stop/2" do
    test "returns correct predictions for stop" do
      prediction = %Predictions.Prediction{
        stop_id: "stop_1",
        seconds_until_arrival: 45,
        direction_id: 1,
        route_id: "Blue",
      }
      prediction_map = %{{"stop_1", 1} => [prediction]}
      table_id = :ets.new(:predictions_engine_test, [:set, :protected, read_concurrency: true])
      :ets.insert(table_id, Enum.into(prediction_map, []))
      assert for_stop(table_id, "stop_1", 1) == [prediction]
      assert for_stop(table_id, "no_entry", 0) == []
    end
  end

  describe "currently_boarding/1" do
    test "returns true when vehicle is boarding" do
      prediction = %Predictions.Prediction{
        stop_id: "stop_1",
        seconds_until_arrival: 15,
        direction_id: 1,
        route_id: "Blue",
      }
      table_id = :ets.new(:predictions_engine_positions, [:set, :protected, read_concurrency: true])
      :ets.insert(table_id, [{"stop_1", true}])
      assert currently_boarding?(table_id,"stop_1")
      refute currently_boarding?(table_id, "stop_2")
    end
  end
end
