defmodule Engine.LocationsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Engine.Locations

  describe "handle_info/2" do
    test "logs error when invalid HTTP response returned" do
      position_url = Application.get_env(:realtime_signs, :vehicle_positions_url)
      Application.put_env(:realtime_signs, :vehicle_positions_url, "vehicle_position_error")

      on_exit(fn ->
        Application.put_env(:realtime_signs, :vehicle_positions_url, position_url)
      end)

      existing_state = %{
        last_modified_vehicle_positions: nil,
        vehicle_locations_table: :test_vehicle_locations
      }

      log =
        capture_log([level: :warn], fn ->
          {:noreply, updated_state} = handle_info(:update, existing_state)
          assert existing_state == updated_state
        end)

      assert log =~ "Could not fetch file "
      assert log =~ "timeout"
    end
  end
end
