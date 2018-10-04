defmodule Predictions.PredictionsTest do
  use ExUnit.Case
  alias Predictions.Prediction
  import Predictions.Predictions

  @current_time Timex.to_datetime(~N[2017-04-07 09:00:00], "America/New_York")
  @feed_message %{
    "entity" => [
      %{
        "alert" => nil,
        "id" => "1490783458_32568935",
        "is_deleted" => false,
        "trip_update" => %{
          "delay" => nil,
          "stop_time_update" => [
            %{
              "arrival" => nil,
              "departure" => %{
                "delay" => nil,
                "time" => 1_491_570_120,
                "uncertainty" => nil
              },
              "schedule_relationship" => "SCHEDULED",
              "stop_id" => "70263",
              "stop_sequence" => 1,
              "stops_away" => 1,
              "stopped?" => true,
              "boarding_status" => "Stopped 1 stop away"
            },
            %{
              "arrival" => %{
                "delay" => nil,
                "time" => 1_491_570_180,
                "uncertainty" => nil
              },
              "departure" => nil,
              "schedule_relationship" => "SCHEDULED",
              "stop_id" => "70261",
              "stops_away" => 1,
              "stopped?" => false,
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
            "trip_id" => "32568935"
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

  describe "get_all/2" do
    test "finds predictions for one trip" do
      expected = %{
        {"70261", 0} => [
          %Predictions.Prediction{
            stop_id: "70261",
            seconds_until_arrival: 180,
            direction_id: 0,
            route_id: "Mattapan",
            stops_away: 1,
            stopped?: false,
            destination_stop_id: "70261"
          }
        ],
        {"70263", 0} => [
          %Predictions.Prediction{
            stop_id: "70263",
            seconds_until_departure: 120,
            direction_id: 0,
            route_id: "Mattapan",
            destination_stop_id: "70261",
            stops_away: 1,
            stopped?: true,
            boarding_status: "Stopped 1 stop away"
          }
        ]
      }

      assert get_all(@feed_message, @current_time) == expected
    end

    test "finds predictions for multiple trips" do
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
                    "time" => 1_491_570_120,
                    "uncertainty" => nil
                  },
                  "departure" => nil,
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70263",
                  "stopped?" => false,
                  "stops_away" => 1,
                  "stop_sequence" => 1
                },
                %{
                  "arrival" => %{
                    "delay" => nil,
                    "time" => 1_491_570_180,
                    "uncertainty" => nil
                  },
                  "departure" => nil,
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70261",
                  "stopped?" => false,
                  "stops_away" => 1,
                  "stop_sequence" => 1
                },
                %{
                  "arrival" => nil,
                  "departure" => nil,
                  "schedule_relationship" => "SCHEDULED",
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
                "trip_id" => "32568935"
              },
              "vehicle" => %{
                "id" => "G-10040",
                "label" => "3260",
                "license_plate" => nil
              }
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
                    "time" => 1_491_570_200,
                    "uncertainty" => nil
                  },
                  "departure" => nil,
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70038",
                  "stopped?" => false,
                  "stops_away" => 1,
                  "stop_sequence" => 1
                },
                %{
                  "arrival" => %{
                    "delay" => nil,
                    "time" => 1_491_570_400,
                    "uncertainty" => nil
                  },
                  "departure" => nil,
                  "schedule_relationship" => "SCHEDULED",
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
                "trip_id" => "trip_2"
              },
              "vehicle" => %{
                "id" => "vehicle_2",
                "label" => "3261",
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
            direction_id: 0,
            route_id: "Mattapan",
            stopped?: false,
            stops_away: 1,
            destination_stop_id: "70261"
          }
        ],
        {"70263", 0} => [
          %Predictions.Prediction{
            stop_id: "70263",
            seconds_until_arrival: 120,
            direction_id: 0,
            route_id: "Mattapan",
            stopped?: false,
            stops_away: 1,
            destination_stop_id: "70261"
          }
        ],
        {"70038", 1} => [
          %Predictions.Prediction{
            stop_id: "70038",
            seconds_until_arrival: 200,
            direction_id: 1,
            route_id: "Blue",
            stopped?: false,
            stops_away: 1,
            destination_stop_id: "70060"
          }
        ],
        {"70060", 1} => [
          %Predictions.Prediction{
            stop_id: "70060",
            seconds_until_arrival: 400,
            direction_id: 1,
            route_id: "Blue",
            stopped?: false,
            stops_away: 1,
            destination_stop_id: "70060"
          }
        ]
      }

      assert get_all(feed_message, @current_time) == expected
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
                    "time" => Timex.to_unix(@current_time) - 100,
                    "uncertainty" => nil
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
                "trip_id" => "32568935"
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

      assert get_all(feed_message, @current_time) == %{
               {"70263", 0} => [
                 %Predictions.Prediction{
                   stop_id: "70263",
                   seconds_until_arrival: 0,
                   direction_id: 0,
                   route_id: "Mattapan",
                   stopped?: false,
                   stops_away: 1,
                   destination_stop_id: "70263"
                 }
               ]
             }
    end
  end

  describe "parse_pb_response/1" do
    test "decodes a pb file" do
      assert @feed_message
             |> Poison.encode!()
             |> parse_json_response == @feed_message
    end

    test "Gracefully handles an empty (e.g. 304) response" do
      assert %{} = parse_json_response("")
    end
  end

  describe "sort/1" do
    test "Sorts predictions in ascending order of seconds_until_arrival" do
      p1 = %Prediction{stops_away: 1, seconds_until_arrival: 500, seconds_until_departure: 180}
      p2 = %Prediction{stops_away: 1, seconds_until_arrival: 120, seconds_until_departure: 120}
      p3 = %Prediction{stops_away: 1, seconds_until_arrival: 45, seconds_until_departure: 500}
      p4 = %Prediction{stops_away: 1, seconds_until_arrival: 180, seconds_until_departure: 45}

      assert sort([p1, p2, p3, p4], :arrival) == [p3, p2, p4, p1]
    end

    test "Sorts predictions in ascending order of seconds_until_departure" do
      p1 = %Prediction{stops_away: 1, seconds_until_departure: 500, seconds_until_arrival: 180}
      p2 = %Prediction{stops_away: 1, seconds_until_departure: 120, seconds_until_arrival: 120}
      p3 = %Prediction{stops_away: 1, seconds_until_departure: 45, seconds_until_arrival: 500}
      p4 = %Prediction{stops_away: 1, seconds_until_departure: 180, seconds_until_arrival: 45}

      assert sort([p1, p2, p3, p4], :departure) == [p3, p2, p4, p1]
    end

    test "Sorts boarding predictions first for arrival predictions" do
      p1 = %Prediction{stops_away: 0, seconds_until_departure: 500, seconds_until_arrival: 180}
      p2 = %Prediction{stops_away: 1, seconds_until_departure: 120, seconds_until_arrival: 120}
      p3 = %Prediction{stops_away: 1, seconds_until_departure: 45, seconds_until_arrival: 500}
      p4 = %Prediction{stops_away: 1, seconds_until_departure: 180, seconds_until_arrival: 45}

      assert sort([p1, p2, p3, p4], :arrival) == [p1, p4, p2, p3]

      p1 = %Prediction{stops_away: 1, seconds_until_departure: 500, seconds_until_arrival: 180}
      p2 = %Prediction{stops_away: 1, seconds_until_departure: 120, seconds_until_arrival: 120}
      p3 = %Prediction{stops_away: 1, seconds_until_departure: 45, seconds_until_arrival: 500}
      p4 = %Prediction{stops_away: 0, seconds_until_departure: 180, seconds_until_arrival: 45}

      assert sort([p1, p2, p3, p4], :arrival) == [p4, p2, p1, p3]
    end

    test "Sorts boarding predictions first for departure predictions" do
      p1 = %Prediction{stops_away: 0, seconds_until_departure: 500, seconds_until_arrival: 180}
      p2 = %Prediction{stops_away: 1, seconds_until_departure: 120, seconds_until_arrival: 120}
      p3 = %Prediction{stops_away: 1, seconds_until_departure: 45, seconds_until_arrival: 500}
      p4 = %Prediction{stops_away: 1, seconds_until_departure: 180, seconds_until_arrival: 45}

      assert sort([p1, p2, p3, p4], :departure) == [p1, p3, p2, p4]

      p1 = %Prediction{stops_away: 1, seconds_until_departure: 500, seconds_until_arrival: 180}
      p2 = %Prediction{stops_away: 1, seconds_until_departure: 120, seconds_until_arrival: 120}
      p3 = %Prediction{stops_away: 1, seconds_until_departure: 45, seconds_until_arrival: 500}
      p4 = %Prediction{stops_away: 0, seconds_until_departure: 180, seconds_until_arrival: 45}

      assert sort([p1, p2, p3, p4], :departure) == [p4, p3, p2, p1]
    end

    test "when multiple predictions are 0 stops away, sorts by arrival or departure depending on the type of predictions" do
      p1 = %Prediction{stops_away: 0, seconds_until_departure: 500, seconds_until_arrival: 180}
      p2 = %Prediction{stops_away: 0, seconds_until_departure: 120, seconds_until_arrival: 120}
      p3 = %Prediction{stops_away: 0, seconds_until_departure: 45, seconds_until_arrival: 500}
      p4 = %Prediction{stops_away: 0, seconds_until_departure: 180, seconds_until_arrival: 45}

      assert sort([p1, p2, p3, p4], :arrival) == [p4, p2, p1, p3]

      p1 = %Prediction{stops_away: 0, seconds_until_departure: 500, seconds_until_arrival: 180}
      p2 = %Prediction{stops_away: 0, seconds_until_departure: 120, seconds_until_arrival: 120}
      p3 = %Prediction{stops_away: 0, seconds_until_departure: 45, seconds_until_arrival: 500}
      p4 = %Prediction{stops_away: 0, seconds_until_departure: 180, seconds_until_arrival: 45}

      assert sort([p1, p2, p3, p4], :departure) == [p3, p2, p4, p1]
    end
  end
end
