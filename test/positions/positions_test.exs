defmodule Positions.PositionsTest do
  use ExUnit.Case, async: true
  import Positions.Positions

  @feed_message %{
    "entity" => [
      %{
        "alert" => nil,
        "id" => "1528987657_G-10131",
        "is_deleted" => false,
        "trip_update" => nil,
        "vehicle" => %{
          "congestion_level" => nil,
          "current_status" => "STOPPED_AT",
          "current_stop_sequence" => 1,
          "occupancy_status" => nil,
          "position" => %{
            "bearing" => 135.0,
            "latitude" => 42.340179443359375,
            "longitude" => -71.1670913696289,
            "odometer" => nil,
            "speed" => nil
          },
          "stop_id" => "70106",
          "timestamp" => 1_528_987_657,
          "trip" => %{
            "direction_id" => 1,
            "route_id" => "Green-B",
            "schedule_relationship" => "SCHEDULED",
            "start_date" => "20180614",
            "start_time" => nil,
            "trip_id" => "36418561"
          },
          "vehicle" => %{
            "id" => "G-10131",
            "label" => "3841-3625",
            "license_plate" => nil
          }
        }
      }
    ],
    "header" => %{
      "gtfs_realtime_version" => "1.0",
      "incrementality" => "FULL_DATASET",
      "timestamp" => 1_490_783_458
    }
  }

  describe "parse_json_response/1" do
    test "parses response" do
      encoded_json = Poison.encode!(@feed_message)
      assert parse_json_response(encoded_json) == @feed_message
    end

    test "handles empty response gracefully" do
      assert %{} = parse_json_response("")
    end
  end

  describe "get_stopped/1" do
    test "gets all stations" do
      assert get_stopped(@feed_message) == [{"70106", true}]
    end
  end
end
