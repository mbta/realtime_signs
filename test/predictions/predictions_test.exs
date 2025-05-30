defmodule Predictions.PredictionsTest do
  use ExUnit.Case
  import Predictions.Predictions
  import Mox

  @current_time Timex.to_datetime(~N[2017-04-07 09:00:00], "America/New_York")
  @feed_message %{
    "entity" => [
      %{
        "id" => "1490783458_32568935",
        "trip_update" => %{
          "stop_time_update" => [
            %{
              "arrival" => nil,
              "departure" => nil,
              "stop_id" => "70265",
              "stop_sequence" => 1
            },
            %{
              "arrival" => nil,
              "departure" => %{
                "time" => 1_491_570_120
              },
              "stop_id" => "70263",
              "stop_sequence" => 1,
              "boarding_status" => "Stopped 1 stop away"
            },
            %{
              "arrival" => %{
                "time" => 1_491_570_180
              },
              "departure" => nil,
              "stop_id" => "70261",
              "stop_sequence" => 1
            }
          ],
          "timestamp" => nil,
          "trip" => %{
            "direction_id" => 0,
            "route_id" => "Mattapan",
            "schedule_relationship" => "SCHEDULED",
            "start_date" => "20170329",
            "start_time" => nil,
            "trip_id" => "32568935",
            "revenue" => true
          },
          "vehicle" => %{
            "id" => "G-10040",
            "label" => "3260",
            "license_plate" => nil
          },
          "update_type" => "mid_trip"
        },
        "vehicle" => nil
      }
    ],
    "header" => %{
      "gtfs_realtime_version" => "1.0",
      "incrementality" => "FULL_DATASET",
      "timestamp" => 1_490_783_458
    }
  }

  describe "get_all/2" do
    setup do
      stub(Engine.Locations.Mock, :for_vehicle, fn _ -> nil end)
      :ok
    end

    test "finds predictions for one trip" do
      expected = %{
        {"70261", 0} => [
          %Predictions.Prediction{
            stop_id: "70261",
            seconds_until_arrival: 180,
            direction_id: 0,
            schedule_relationship: :scheduled,
            route_id: "Mattapan",
            destination_stop_id: "70261",
            trip_id: "32568935",
            revenue_trip?: true,
            vehicle_id: "G-10040",
            type: :mid_trip
          }
        ],
        {"70263", 0} => [
          %Predictions.Prediction{
            stop_id: "70263",
            seconds_until_departure: 120,
            direction_id: 0,
            schedule_relationship: :scheduled,
            route_id: "Mattapan",
            destination_stop_id: "70261",
            boarding_status: "Stopped 1 stop away",
            trip_id: "32568935",
            revenue_trip?: true,
            vehicle_id: "G-10040",
            type: :mid_trip
          }
        ]
      }

      assert {^expected, _} = get_all(@feed_message, @current_time)
    end

    test "finds predictions for multiple trips, excluding canceled trips" do
      feed_message = %{
        "entity" => [
          %{
            "alert" => nil,
            "id" => "1490783458_32568935",
            "is_deleted" => false,
            "trip_update" => %{
              "delay" => nil,
              "stop_time_update" => [
                %{
                  "arrival" => %{
                    "delay" => nil,
                    "time" => 1_491_570_120
                  },
                  "departure" => nil,
                  "stop_id" => "70263",
                  "stopped?" => false,
                  "stops_away" => 1,
                  "stop_sequence" => 1
                },
                %{
                  "arrival" => %{
                    "delay" => nil,
                    "time" => 1_491_570_180
                  },
                  "departure" => nil,
                  "stop_id" => "70261",
                  "stopped?" => false,
                  "stops_away" => 1,
                  "stop_sequence" => 1
                },
                %{
                  "arrival" => nil,
                  "departure" => nil,
                  "stop_id" => "70261",
                  "stopped?" => false,
                  "stops_away" => 1,
                  "stop_sequence" => 1
                }
              ],
              "timestamp" => nil,
              "trip" => %{
                "direction_id" => 0,
                "route_id" => "Mattapan",
                "schedule_relationship" => "SCHEDULED",
                "start_date" => "20170329",
                "start_time" => nil,
                "trip_id" => "32568935",
                "revenue" => true
              },
              "vehicle" => %{
                "id" => "G-10040",
                "label" => "3260",
                "license_plate" => nil
              },
              "update_type" => "mid_trip"
            },
            "vehicle" => nil
          },
          %{
            "alert" => nil,
            "id" => "id_2",
            "is_deleted" => false,
            "trip_update" => %{
              "delay" => nil,
              "stop_time_update" => [
                %{
                  "arrival" => %{
                    "delay" => nil,
                    "time" => 1_491_570_200
                  },
                  "departure" => nil,
                  "stop_id" => "70038",
                  "stopped?" => false,
                  "stops_away" => 1,
                  "stop_sequence" => 1
                },
                %{
                  "arrival" => %{
                    "delay" => nil,
                    "time" => 1_491_570_400
                  },
                  "departure" => nil,
                  "stop_id" => "70060",
                  "stopped?" => false,
                  "stops_away" => 1,
                  "stop_sequence" => 1
                }
              ],
              "timestamp" => nil,
              "trip" => %{
                "direction_id" => 1,
                "route_id" => "Blue",
                "schedule_relationship" => "SCHEDULED",
                "start_date" => "20170329",
                "start_time" => nil,
                "trip_id" => "trip_2",
                "revenue" => true
              },
              "vehicle" => %{
                "id" => "vehicle_2",
                "label" => "3261",
                "license_plate" => nil
              },
              "update_type" => "mid_trip"
            },
            "vehicle" => nil
          },
          %{
            "alert" => nil,
            "id" => "1566418052_40826503",
            "is_deleted" => false,
            "trip_update" => %{
              "delay" => nil,
              "stop_time_update" => [],
              "timestamp" => nil,
              "trip" => %{
                "direction_id" => nil,
                "route_id" => nil,
                "schedule_relationship" => "CANCELED",
                "start_date" => "20190821",
                "start_time" => nil,
                "trip_id" => "40826503",
                "revenue" => true
              },
              "vehicle" => %{
                "id" => nil,
                "label" => nil,
                "license_plate" => nil
              }
            },
            "vehicle" => nil
          }
        ],
        "header" => %{
          "gtfs_realtime_version" => "1.0",
          "incrementality" => "FULL_DATASET",
          "timestamp" => 1_490_783_458
        }
      }

      expected = %{
        {"70261", 0} => [
          %Predictions.Prediction{
            stop_id: "70261",
            seconds_until_arrival: 180,
            schedule_relationship: :scheduled,
            direction_id: 0,
            route_id: "Mattapan",
            destination_stop_id: "70261",
            trip_id: "32568935",
            revenue_trip?: true,
            vehicle_id: "G-10040",
            type: :mid_trip
          }
        ],
        {"70263", 0} => [
          %Predictions.Prediction{
            stop_id: "70263",
            seconds_until_arrival: 120,
            direction_id: 0,
            schedule_relationship: :scheduled,
            route_id: "Mattapan",
            destination_stop_id: "70261",
            trip_id: "32568935",
            revenue_trip?: true,
            vehicle_id: "G-10040",
            type: :mid_trip
          }
        ],
        {"70038", 1} => [
          %Predictions.Prediction{
            stop_id: "70038",
            seconds_until_arrival: 200,
            direction_id: 1,
            schedule_relationship: :scheduled,
            route_id: "Blue",
            destination_stop_id: "70060",
            trip_id: "trip_2",
            revenue_trip?: true,
            vehicle_id: "vehicle_2",
            type: :mid_trip
          }
        ],
        {"70060", 1} => [
          %Predictions.Prediction{
            stop_id: "70060",
            seconds_until_arrival: 400,
            direction_id: 1,
            schedule_relationship: :scheduled,
            route_id: "Blue",
            destination_stop_id: "70060",
            trip_id: "trip_2",
            revenue_trip?: true,
            vehicle_id: "vehicle_2",
            type: :mid_trip
          }
        ]
      }

      assert {^expected, _} = get_all(feed_message, @current_time)
    end

    test "does not let seconds_until_arrival be negative" do
      feed_message = %{
        "entity" => [
          %{
            "alert" => nil,
            "id" => "1490783458_32568935",
            "is_deleted" => false,
            "trip_update" => %{
              "delay" => nil,
              "stop_time_update" => [
                %{
                  "arrival" => %{
                    "delay" => nil,
                    "time" => Timex.to_unix(@current_time) - 100
                  },
                  "departure" => nil,
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70263",
                  "stopped?" => false,
                  "stops_away" => 1,
                  "stop_sequence" => 1
                }
              ],
              "timestamp" => nil,
              "trip" => %{
                "direction_id" => 0,
                "route_id" => "Mattapan",
                "schedule_relationship" => "SCHEDULED",
                "start_date" => "20170329",
                "start_time" => nil,
                "trip_id" => "32568935",
                "revenue" => true
              },
              "vehicle" => %{
                "id" => "G-10040",
                "label" => "3260",
                "license_plate" => nil
              }
            },
            "vehicle" => nil
          }
        ],
        "header" => %{
          "gtfs_realtime_version" => "1.0",
          "incrementality" => "FULL_DATASET",
          "timestamp" => 1_490_783_458
        }
      }

      assert {%{
                {"70263", 0} => [
                  %Predictions.Prediction{
                    stop_id: "70263",
                    seconds_until_arrival: 0,
                    direction_id: 0,
                    schedule_relationship: :scheduled,
                    route_id: "Mattapan",
                    destination_stop_id: "70263",
                    trip_id: "32568935",
                    revenue_trip?: true,
                    vehicle_id: "G-10040"
                  }
                ]
              }, _} = get_all(feed_message, @current_time)
    end
  end
end
