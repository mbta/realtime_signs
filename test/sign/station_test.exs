defmodule Sign.StationTest do
  use ExUnit.Case, async: true
  import Sign.Station
  alias Sign.Station

  describe "zone_ids/1" do
    test "returns zone ids for station" do
      station = %Station{stop_id: "Stop1", zones: %{0 => :northbound, 1 => :southbound}}
      assert zone_ids(station) == [0, 1]
    end
  end
end
