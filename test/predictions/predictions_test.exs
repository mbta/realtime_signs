defmodule Predictions.PredictionsTest do
  use ExUnit.Case
  import Predictions.Predictions
  import Test.Support.Helpers

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
              "departure" => nil,
              "schedule_relationship" => "SKIPPED",
              "stop_id" => "70265",
              "stop_sequence" => 1,
              "stops_away" => nil,
              "stopped?" => false,
              "passthrough_time" => 1_491_570_110
            },
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
            schedule_relationship: :scheduled,
            route_id: "Mattapan",
            stops_away: 1,
            stopped?: false,
            destination_stop_id: "70261",
            trip_id: "32568935",
            revenue_trip?: true,
            vehicle_id: "G-10040"
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
            stops_away: 1,
            stopped?: true,
            boarding_status: "Stopped 1 stop away",
            trip_id: "32568935",
            revenue_trip?: true,
            vehicle_id: "G-10040"
          }
        ],
        {"70265", 0} => [
          %Predictions.Prediction{
            stop_id: "70265",
            seconds_until_passthrough: 110,
            direction_id: 0,
            schedule_relationship: :skipped,
            route_id: "Mattapan",
            destination_stop_id: "70261",
            stops_away: nil,
            stopped?: false,
            trip_id: "32568935",
            revenue_trip?: true,
            vehicle_id: "G-10040"
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
                "trip_id" => "40826503"
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
            stopped?: false,
            stops_away: 1,
            destination_stop_id: "70261",
            trip_id: "32568935",
            revenue_trip?: true,
            vehicle_id: "G-10040"
          }
        ],
        {"70263", 0} => [
          %Predictions.Prediction{
            stop_id: "70263",
            seconds_until_arrival: 120,
            direction_id: 0,
            schedule_relationship: :scheduled,
            route_id: "Mattapan",
            stopped?: false,
            stops_away: 1,
            destination_stop_id: "70261",
            trip_id: "32568935",
            revenue_trip?: true,
            vehicle_id: "G-10040"
          }
        ],
        {"70038", 1} => [
          %Predictions.Prediction{
            stop_id: "70038",
            seconds_until_arrival: 200,
            direction_id: 1,
            schedule_relationship: :scheduled,
            route_id: "Blue",
            stopped?: false,
            stops_away: 1,
            destination_stop_id: "70060",
            trip_id: "trip_2",
            revenue_trip?: true,
            vehicle_id: "vehicle_2"
          }
        ],
        {"70060", 1} => [
          %Predictions.Prediction{
            stop_id: "70060",
            seconds_until_arrival: 400,
            direction_id: 1,
            schedule_relationship: :scheduled,
            route_id: "Blue",
            stopped?: false,
            stops_away: 1,
            destination_stop_id: "70060",
            trip_id: "trip_2",
            revenue_trip?: true,
            vehicle_id: "vehicle_2"
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

      assert {%{
                {"70263", 0} => [
                  %Predictions.Prediction{
                    stop_id: "70263",
                    seconds_until_arrival: 0,
                    direction_id: 0,
                    schedule_relationship: :scheduled,
                    route_id: "Mattapan",
                    stopped?: false,
                    stops_away: 1,
                    destination_stop_id: "70263",
                    trip_id: "32568935",
                    revenue_trip?: true,
                    vehicle_id: "G-10040"
                  }
                ]
              }, _} = get_all(feed_message, @current_time)
    end

    test "filters stop_time_updates where stops_away == nil" do
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
                  "departure" => %{
                    "delay" => nil,
                    "time" => Timex.to_unix(@current_time) - 100,
                    "uncertainty" => nil
                  },
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70262",
                  "stopped?" => false,
                  "stops_away" => nil,
                  "stop_sequence" => 1
                },
                %{
                  "arrival" => nil,
                  "departure" => %{
                    "delay" => nil,
                    "time" => Timex.to_unix(@current_time) - 100,
                    "uncertainty" => nil
                  },
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70263",
                  "stopped?" => false,
                  "stops_away" => nil,
                  "stop_sequence" => 1
                },
                %{
                  "arrival" => nil,
                  "departure" => %{
                    "delay" => nil,
                    "time" => Timex.to_unix(@current_time) + 100,
                    "uncertainty" => nil
                  },
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70264",
                  "stopped?" => false,
                  "stops_away" => 1,
                  "stop_sequence" => 2
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

      {predictions_map, _} = get_all(feed_message, @current_time)

      assert predictions_map == %{
               {"70264", 0} => [
                 %Predictions.Prediction{
                   boarding_status: nil,
                   destination_stop_id: "70262",
                   direction_id: 0,
                   revenue_trip?: true,
                   route_id: "Mattapan",
                   schedule_relationship: :scheduled,
                   seconds_until_arrival: nil,
                   seconds_until_departure: 100,
                   seconds_until_passthrough: nil,
                   stop_id: "70264",
                   stopped?: false,
                   stops_away: 1,
                   trip_id: "32568935",
                   vehicle_id: "G-10040"
                 }
               ]
             }
    end

    test "include predictions with low uncertainty" do
      reassign_env(:filter_uncertain_predictions?, true)

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
                  "arrival" => nil,
                  "departure" => %{
                    "delay" => nil,
                    "time" => 1_491_570_120,
                    "uncertainty" => 60
                  },
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70063",
                  "stop_sequence" => 1,
                  "stops_away" => 1,
                  "stopped?" => true,
                  "boarding_status" => "Stopped 1 stop away"
                }
              ],
              "timestamp" => nil,
              "trip" => %{
                "direction_id" => 0,
                "route_id" => "Red",
                "schedule_relationship" => "SCHEDULED",
                "start_date" => "20170329",
                "start_time" => nil,
                "trip_id" => "32568935"
              },
              "vehicle" => %{
                "id" => "R-54639F6C",
                "label" => "1631",
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
                {"70063", 0} => [
                  %Predictions.Prediction{
                    seconds_until_departure: 120
                  }
                ]
              }, _} = get_all(feed_message, @current_time)
    end

    test "filter predictions with high uncertainty" do
      reassign_env(:filter_uncertain_predictions?, true)

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
                    "time" => 1_491_570_110,
                    "uncertainty" => 360
                  },
                  "departure" => %{
                    "delay" => nil,
                    "time" => 1_491_570_120,
                    "uncertainty" => 360
                  },
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70063",
                  "stop_sequence" => 1,
                  "stops_away" => 1,
                  "stopped?" => true,
                  "boarding_status" => "Stopped 1 stop away"
                }
              ],
              "timestamp" => nil,
              "trip" => %{
                "direction_id" => 0,
                "route_id" => "Blue",
                "schedule_relationship" => "SCHEDULED",
                "start_date" => "20170329",
                "start_time" => nil,
                "trip_id" => "32568935"
              },
              "vehicle" => %{
                "id" => "R-54639F6C",
                "label" => "1631",
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

      {predictions_map, _} = get_all(feed_message, @current_time)

      assert predictions_map == %{}
    end

    test "doesn't filter predictions with high uncertainty when feature is off" do
      reassign_env(:filter_uncertain_predictions?, false)

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
                    "time" => 1_491_570_110,
                    "uncertainty" => 360
                  },
                  "departure" => %{
                    "delay" => nil,
                    "time" => 1_491_570_120,
                    "uncertainty" => 360
                  },
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70063",
                  "stop_sequence" => 1,
                  "stops_away" => 1,
                  "stopped?" => true,
                  "boarding_status" => "Stopped 1 stop away"
                }
              ],
              "timestamp" => nil,
              "trip" => %{
                "direction_id" => 0,
                "route_id" => "Red",
                "schedule_relationship" => "SCHEDULED",
                "start_date" => "20170329",
                "start_time" => nil,
                "trip_id" => "32568935"
              },
              "vehicle" => %{
                "id" => "R-54639F6C",
                "label" => "1631",
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
                {"70063", 0} => [
                  %Predictions.Prediction{
                    seconds_until_arrival: 110,
                    seconds_until_departure: 120
                  }
                ]
              }, _} = get_all(feed_message, @current_time)
    end

    test "doesn't filter out uncertain light rail predictions" do
      reassign_env(:filter_uncertain_predictions?, true)

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
                    "time" => 1_491_570_110,
                    "uncertainty" => 360
                  },
                  "departure" => %{
                    "delay" => nil,
                    "time" => 1_491_570_120,
                    "uncertainty" => 360
                  },
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70263",
                  "stop_sequence" => 1,
                  "stops_away" => 1,
                  "stopped?" => true,
                  "boarding_status" => "Stopped 1 stop away"
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

      assert {%{
                {"70263", 0} => [
                  %Predictions.Prediction{
                    seconds_until_arrival: 110,
                    seconds_until_departure: 120
                  }
                ]
              }, _} = get_all(feed_message, @current_time)
    end
  end

  describe "parse_pb_response/1" do
    test "decodes a pb file" do
      assert @feed_message
             |> Jason.encode!()
             |> parse_json_response == @feed_message
    end

    test "Gracefully handles an empty (e.g. 304) response" do
      assert %{} = parse_json_response("")
    end
  end
end
