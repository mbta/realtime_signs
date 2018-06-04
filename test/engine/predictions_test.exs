defmodule Engine.PredictionsTest do
  use ExUnit.Case, async: true
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
  end
end
