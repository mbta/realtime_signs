defmodule Engine.Alerts.StationConfigTest do
  use ExUnit.Case, async: true

  test "loads the config correctly" do
    %{
      stop_to_station: stop_to_station,
      station_to_stops: station_to_stops,
      station_neighbors: station_neighbors
    } = Engine.Alerts.StationConfig.load_config()

    assert stop_to_station["70200"] == "G Park St"

    assert Enum.sort(station_to_stops["G Park St"]) == [
             "70196",
             "70197",
             "70198",
             "70199",
             "70200"
           ]

    assert Enum.sort(station_neighbors["G Copley"]) == ["G Arlington", "G Hynes", "G Prudential"]
  end
end
