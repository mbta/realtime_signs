defmodule Predictions.PredictionsTest do
  use ExUnit.Case
  import Predictions.Predictions

  @current_time Timex.to_datetime(~N[2017-04-07 09:00:00], "America/New_York")
  @feed_message %GTFS.Realtime.FeedMessage{entity: [%GTFS.Realtime.FeedEntity{alert: nil,
     id: "1490783458_32568935", is_deleted: false, trip_update: %GTFS.Realtime.TripUpdate{delay: nil,
      stop_time_update: [%GTFS.Realtime.TripUpdate.StopTimeUpdate{arrival: %GTFS.Realtime.TripUpdate.StopTimeEvent{delay: nil,
         time: 1491570120, uncertainty: nil},
        departure: nil, schedule_relationship: :SCHEDULED,
        stop_id: "70263", stop_sequence: 1},
      %GTFS.Realtime.TripUpdate.StopTimeUpdate{arrival: %GTFS.Realtime.TripUpdate.StopTimeEvent{delay: nil,
         time: 1491570180, uncertainty: nil},
        departure: nil, schedule_relationship: :SCHEDULED,
        stop_id: "70261", stop_sequence: 1}], timestamp: nil,
      trip: %GTFS.Realtime.TripDescriptor{direction_id: 0, route_id: "Mattapan",
       schedule_relationship: :SCHEDULED, start_date: "20170329", start_time: nil,
       trip_id: "32568935"},
      vehicle: %GTFS.Realtime.VehicleDescriptor{id: "G-10040", label: "3260",
       license_plate: nil}}, vehicle: nil}],
   header: %GTFS.Realtime.FeedHeader{gtfs_realtime_version: "1.0",
    incrementality: :FULL_DATASET, timestamp: 1490783458}}

  describe "get_all/2" do
    test "finds predictions for one trip" do
      expected = %{"70261" => [
          %Predictions.Prediction{stop_id: "70261", seconds_until_arrival: 180, direction_id: 0, route_id: "Mattapan"},
        ],
        "70263" => [
          %Predictions.Prediction{stop_id: "70263", seconds_until_arrival: 120, direction_id: 0, route_id: "Mattapan"}
        ]
      }
      assert get_all(@feed_message,  @current_time) == expected
    end

    test "finds predictions for multiple trips" do
      feed_message = %GTFS.Realtime.FeedMessage{entity: [%GTFS.Realtime.FeedEntity{alert: nil,
           id: "1490783458_32568935", is_deleted: false, trip_update: %GTFS.Realtime.TripUpdate{delay: nil,
            stop_time_update: [%GTFS.Realtime.TripUpdate.StopTimeUpdate{arrival: %GTFS.Realtime.TripUpdate.StopTimeEvent{delay: nil,
               time: 1491570120, uncertainty: nil},
              departure: nil, schedule_relationship: :SCHEDULED,
              stop_id: "70263", stop_sequence: 1},
            %GTFS.Realtime.TripUpdate.StopTimeUpdate{arrival: %GTFS.Realtime.TripUpdate.StopTimeEvent{delay: nil,
               time: 1491570180, uncertainty: nil},
              departure: nil, schedule_relationship: :SCHEDULED,
              stop_id: "70261", stop_sequence: 1},%GTFS.Realtime.TripUpdate.StopTimeUpdate{arrival: nil,
              departure: nil, schedule_relationship: :SCHEDULED,
              stop_id: "70261", stop_sequence: 1}], timestamp: nil,
            trip: %GTFS.Realtime.TripDescriptor{direction_id: 0, route_id: "Mattapan",
             schedule_relationship: :SCHEDULED, start_date: "20170329", start_time: nil,
             trip_id: "32568935"},
            vehicle: %GTFS.Realtime.VehicleDescriptor{id: "G-10040", label: "3260",
             license_plate: nil}}, vehicle: nil},
        %GTFS.Realtime.FeedEntity{alert: nil,
           id: "id_2", is_deleted: false, trip_update: %GTFS.Realtime.TripUpdate{delay: nil,
            stop_time_update: [%GTFS.Realtime.TripUpdate.StopTimeUpdate{arrival: %GTFS.Realtime.TripUpdate.StopTimeEvent{delay: nil,
               time: 1491570200, uncertainty: nil},
              departure: nil, schedule_relationship: :SCHEDULED,
              stop_id: "Bowdoin", stop_sequence: 1},
            %GTFS.Realtime.TripUpdate.StopTimeUpdate{arrival: %GTFS.Realtime.TripUpdate.StopTimeEvent{delay: nil,
               time: 1491570400, uncertainty: nil},
              departure: nil, schedule_relationship: :SCHEDULED,
              stop_id: "Wonderland", stop_sequence: 1}], timestamp: nil,
            trip: %GTFS.Realtime.TripDescriptor{direction_id: 1, route_id: "Blue",
             schedule_relationship: :SCHEDULED, start_date: "20170329", start_time: nil,
             trip_id: "trip_2"},
            vehicle: %GTFS.Realtime.VehicleDescriptor{id: "vehicle_2", label: "3261",
             license_plate: nil}}, vehicle: nil}],
         header: %GTFS.Realtime.FeedHeader{gtfs_realtime_version: "1.0",
          incrementality: :FULL_DATASET, timestamp: 1490783458}}

      expected = %{"70261" => [%Predictions.Prediction{stop_id: "70261", seconds_until_arrival: 180, direction_id: 0, route_id: "Mattapan"} ],
        "70263" => [%Predictions.Prediction{stop_id: "70263", seconds_until_arrival: 120, direction_id: 0, route_id: "Mattapan"}],
        "Bowdoin" => [%Predictions.Prediction{stop_id: "Bowdoin", seconds_until_arrival: 200, direction_id: 1, route_id: "Blue"}],
        "Wonderland" => [%Predictions.Prediction{stop_id: "Wonderland", seconds_until_arrival: 400, direction_id: 1, route_id: "Blue"}]
      }
      assert get_all(feed_message,  @current_time) == expected
    end
  end

  describe "parse_pb_response/1" do
    test "decodes a pb file" do
      assert @feed_message
      |> GTFS.Realtime.FeedMessage.encode
      |> parse_pb_response == @feed_message
    end
  end
end
