defmodule Engine.PredictionsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Engine.Predictions
  import Mox

  describe "handle_info/2" do
    test "keeps existing states when trip_update url has not been modified" do
      trip_update_url = Application.get_env(:realtime_signs, :trip_update_url)
      Application.put_env(:realtime_signs, :trip_update_url, "trip_updates_304")

      on_exit(fn ->
        Application.put_env(:realtime_signs, :trip_update_url, trip_update_url)
      end)

      existing_state = %Engine.Predictions{}

      {:noreply, ^existing_state} = handle_info(:update, existing_state)
    end

    test "logs error when invalid HTTP response returned" do
      trip_update_url = Application.get_env(:realtime_signs, :trip_update_url)
      Application.put_env(:realtime_signs, :trip_update_url, "trip_updates_error")

      on_exit(fn ->
        Application.put_env(:realtime_signs, :trip_update_url, trip_update_url)
      end)

      existing_state = %Engine.Predictions{}

      log =
        capture_log([level: :warning], fn ->
          {:noreply, ^existing_state} = handle_info(:update, existing_state)
        end)

      assert log =~ "Could not fetch "
      assert log =~ "timeout"
    end

    test "instead of deleting old predictions, overwrites them with []" do
      stub(Engine.Locations.Mock, :for_vehicle, fn _ -> nil end)
      trip_update_url = Application.get_env(:realtime_signs, :trip_update_url)
      Application.put_env(:realtime_signs, :trip_update_url, "fake_trip_update2.json")

      on_exit(fn ->
        Application.put_env(:realtime_signs, :trip_update_url, trip_update_url)
      end)

      predictions_table =
        :ets.new(:test_vehicle_predictions, [:named_table, read_concurrency: true])

      revenue_vehicles_table =
        :ets.new(:test_revenue_vehicles, [:named_table, read_concurrency: true])

      :ets.insert(predictions_table, [
        {{"stop_to_remove", 0}, true},
        {{"stop_to_update", 0}, true}
      ])

      existing_state = %Engine.Predictions{
        trip_updates_table: predictions_table,
        revenue_vehicles_table: revenue_vehicles_table
      }

      handle_info(:update, existing_state)

      assert :ets.info(predictions_table)[:size] == 2
      [{{"stop_to_remove", 0}, []}] = :ets.lookup(predictions_table, {"stop_to_remove", 0})

      [{{"stop_to_update", 0}, [%Predictions.Prediction{}]}] =
        :ets.lookup(predictions_table, {"stop_to_update", 0})
    end

    test "logs a warning on any message but :update" do
      existing_state = %Engine.Predictions{}

      log =
        capture_log([level: :info], fn ->
          {:noreply, ^existing_state} = handle_info(:unrecognized, existing_state)
        end)

      assert log =~ "unknown message: :unrecognized"
    end
  end

  describe "for_stop/2" do
    test "returns correct predictions for stop" do
      prediction = %Predictions.Prediction{
        stop_id: "stop_1",
        seconds_until_arrival: 45,
        direction_id: 1,
        route_id: "Blue"
      }

      prediction_map = %{{"stop_1", 1} => [prediction], {"overwritten_stop", 1} => []}
      table_id = :ets.new(:predictions_engine_test, [:set, :protected, read_concurrency: true])
      :ets.insert(table_id, Enum.into(prediction_map, []))
      assert for_stop(table_id, "stop_1", 1) == [prediction]
      assert for_stop(table_id, "overwritten_stop", 1) == []
      assert for_stop(table_id, "no_entry", 0) == []
    end
  end
end
