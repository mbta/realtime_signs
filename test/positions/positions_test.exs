defmodule Positions.PositionsTest do
  use ExUnit.Case, async: true
  import Positions.Positions

  @feed_message %GTFS.Realtime.FeedMessage{
    entity: [
      %GTFS.Realtime.FeedEntity{
        alert: nil,
        id: "1528987657_G-10131",
        is_deleted: false,
        trip_update: nil,
        vehicle: %GTFS.Realtime.VehiclePosition{
          congestion_level: nil,
          current_status: :STOPPED_AT,
          current_stop_sequence: 1,
          occupancy_status: nil,
          position: %GTFS.Realtime.Position{
            bearing: 135.0,
            latitude: 42.340179443359375,
            longitude: -71.1670913696289,
            odometer: nil,
            speed: nil
          },
          stop_id: "70106",
          timestamp: 1_528_987_657,
          trip: %GTFS.Realtime.TripDescriptor{
            direction_id: 1,
            route_id: "Green-B",
            schedule_relationship: :SCHEDULED,
            start_date: "20180614",
            start_time: nil,
            trip_id: "36418561"
          },
          vehicle: %GTFS.Realtime.VehicleDescriptor{
            id: "G-10131",
            label: "3841-3625",
            license_plate: nil
          }
        }
      }
    ],
    header: %GTFS.Realtime.FeedHeader{
      gtfs_realtime_version: "1.0",
      incrementality: :FULL_DATASET,
      timestamp: 1_490_783_458
    }
  }

  describe "parse_pb_response/1" do
    test "parses response" do
      encoded_pb = GTFS.Realtime.FeedMessage.encode(@feed_message)
      assert parse_pb_response(encoded_pb) == @feed_message
    end
  end

  describe "get_stopped/1" do
    test "gets all stations" do
      assert get_stopped(@feed_message) == [{"70106", true}]
    end
  end
end
