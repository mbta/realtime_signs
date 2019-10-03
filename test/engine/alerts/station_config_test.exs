defmodule Engine.Alerts.StationConfigTest do
  use ExUnit.Case, async: true

  test "loads the config correctly" do
    %{
      stop_to_station: stop_to_station,
      station_to_stops: station_to_stops,
      station_neighbors: station_neighbors
    } = Engine.Alerts.StationConfig.load_config()

    assert stop_to_station["70200"] == "G Park St eastbound"

    assert Enum.sort(station_to_stops["G Park St westbound"]) == [
             "70196",
             "70197",
             "70198",
             "70199"
           ]

    assert Enum.sort(station_neighbors["G Copley eastbound"]) == [
             "G Arlington eastbound",
             "G Hynes eastbound",
             "G Prudential eastbound"
           ]
  end
end
