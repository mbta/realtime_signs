defmodule Engine.PredictionsTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import Engine.Predictions

  describe "handle_info/2" do
    test "keeps existing state when trip_update url has not been modified" do
      trip_update_url = Application.get_env(:realtime_signs, :trip_update_url)
      Application.put_env(:realtime_signs, :trip_update_url, "trip_updates_304")
      existing_state = ~N[2017-07-04 09:05:00]
      {:noreply, updated_state} = handle_info(:update, existing_state)
      Application.put_env(:realtime_signs, :trip_update_url, trip_update_url)
      assert updated_state == existing_state
    end

    test "logs error when invalid HTTP response returned" do
      trip_update_url = Application.get_env(:realtime_signs, :trip_update_url)
      Application.put_env(:realtime_signs, :trip_update_url, "trip_updates_error")
      existing_state = ~N[2017-07-04 09:05:00]
      log = capture_log [level: :warn], fn ->
        {:noreply, last_modified} = handle_info(:update, existing_state)
        assert existing_state == last_modified
      end
      Application.put_env(:realtime_signs, :trip_update_url, trip_update_url)
      assert log =~ "Could not fetch pb file: "
      assert log =~ "timeout"
    end
  end
end
