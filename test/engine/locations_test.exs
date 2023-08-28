defmodule Engine.LocationsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  @state %{
    last_modified_vehicle_positions: nil,
    vehicle_locations_table: :test_vehicle_locations,
    stop_locations_table: :test_stop_locations
  }

  describe "handle_info/2" do
    test "logs error when invalid HTTP response returned" do
      position_url = Application.get_env(:realtime_signs, :vehicle_positions_url)
      Application.put_env(:realtime_signs, :vehicle_positions_url, "vehicle_position_error")

      on_exit(fn ->
        Application.put_env(:realtime_signs, :vehicle_positions_url, position_url)
      end)

      log =
        capture_log([level: :warn], fn ->
          {:noreply, updated_state} = Engine.Locations.handle_info(:update, @state)
          assert @state == updated_state
        end)

      assert log =~ "Could not fetch file "
      assert log =~ "timeout"
    end

    test "overwrites old locations data with :none" do
      position_url = Application.get_env(:realtime_signs, :vehicle_positions_url)
      Application.put_env(:realtime_signs, :vehicle_positions_url, "fake_vehicle_position.json")

      on_exit(fn ->
        Application.put_env(:realtime_signs, :vehicle_positions_url, position_url)
      end)

      Engine.Locations.create_tables(@state)

      :ets.insert(:test_vehicle_locations, [
        {"vehicle_1", %{vehicle: "1"}},
        {"vehicle_2", %{vehicle: "2"}}
      ])

      {:noreply, updated_state} = Engine.Locations.handle_info(:update, @state)

      assert updated_state == @state

      assert :ets.tab2list(:test_vehicle_locations) == [
               {"vehicle_2", :none},
               {"vehicle_1", :none}
             ]
    end
  end

  describe "for_vehicle/1" do
    test "return correct location for vehicle" do
      location = %Locations.Location{
        vehicle_id: "vehicle_1",
        status: :incoming_at,
        stop_id: "stop_1"
      }

      location_map = %{"vehicle_1" => location, "vehicle_no_longer_in_feed" => :none}

      Engine.Locations.create_tables(@state)

      :ets.insert(:test_vehicle_locations, Enum.into(location_map, []))
      assert Engine.Locations.for_vehicle(:test_vehicle_locations, "vehicle_1") == location

      assert Engine.Locations.for_vehicle(:test_vehicle_locations, "vehicle_no_longer_in_feed") ==
               nil

      assert Engine.Locations.for_vehicle(:test_vehicle_locations, "vehicle_does_not_exist") ==
               nil
    end
  end
end
