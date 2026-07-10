defmodule Fake.Req do
  def get(url, _options \\ []), do: mock_response(url)

  def post(_url, options \\ []) do
    form = Keyword.fetch!(options, :form)

    case form do
      %{"grant_type" => _} ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"access_token" => "test_access_token", "expires_in" => 2_591_999}
         }}
    end
  end

  @spec mock_response(String.t()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def mock_response("https://fake_update/mbta-gtfs-s3/fake_trip_update.json") do
    feed_message =
      %{
        "entity" => [
          %{
            "id" => "1490783458_32568935",
            "trip_update" => %{
              "stop_time_update" => [
                %{
                  "arrival" => %{
                    "time" => 1_491_570_120
                  },
                  "departure" => nil,
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70263",
                  "stop_sequence" => 1
                },
                %{
                  "arrival" => %{
                    "time" => 1_491_570_180
                  },
                  "departure" => nil,
                  "schedule_relationship" => "SCHEDULED",
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

    {:ok,
     %Req.Response{
       status: 200,
       body: feed_message,
       headers: %{"last-modified" => ["Wed, 29 Mar 2017 10:30:58 GMT"]}
     }}
  end

  def mock_response("https://screenplay-fake.mbtace.com/api/pa-messages/active") do
    response = [
      %{
        "alert_id" => nil,
        "audio_text" =>
          "This is an example of a PA message that will be played at an MBTA station",
        "audio_url" => nil,
        "days_of_week" => [1, 2, 3, 4, 5, 6, 7],
        "end_time" => "2033-12-05T23:53:23Z",
        "id" => 4,
        "inserted_at" => "2024-06-03T18:33:31Z",
        "interval_in_minutes" => 2,
        "message_type" => nil,
        "paused" => nil,
        "priority" => 1,
        "saved" => nil,
        "sign_ids" => [],
        "start_time" => "2024-06-03T18:33:23Z",
        "updated_at" => "2024-06-03T18:33:31Z",
        "visual_text" =>
          "This is an example of a PA message that will be played at an MBTA station"
      },
      %{
        "alert_id" => nil,
        "audio_text" => "This is another PA message that will play at MBTA stations",
        "audio_url" => nil,
        "days_of_week" => [1, 2, 3, 4, 5, 6, 7],
        "end_time" => "2027-08-05T05:41:10Z",
        "id" => 5,
        "inserted_at" => "2024-06-03T19:54:40Z",
        "interval_in_minutes" => 3,
        "message_type" => nil,
        "paused" => nil,
        "priority" => 1,
        "saved" => nil,
        "sign_ids" => [],
        "start_time" => "2024-06-03T19:54:30Z",
        "updated_at" => "2024-06-03T19:54:40Z",
        "visual_text" => "This is another PA message that will play at MBTA stations"
      }
    ]

    {:ok, %Req.Response{status: 200, body: response}}
  end

  def mock_response("https://screenplay-fake.mbtace.com/api/pa-messages/no-longer-active") do
    response = [
      %{
        "alert_id" => nil,
        "audio_text" => "This is another PA message that will play at MBTA stations",
        "audio_url" => nil,
        "days_of_week" => [1, 2, 3, 4, 5, 6, 7],
        "end_time" => "2027-08-05T05:41:10Z",
        "id" => 5,
        "inserted_at" => "2024-06-03T19:54:40Z",
        "interval_in_minutes" => 2,
        "message_type" => nil,
        "paused" => nil,
        "priority" => 1,
        "saved" => nil,
        "sign_ids" => [],
        "start_time" => "2024-06-03T19:54:30Z",
        "updated_at" => "2024-06-03T19:54:40Z",
        "visual_text" => "This is another PA message that will play at MBTA stations"
      }
    ]

    {:ok, %Req.Response{status: 200, body: response}}
  end

  def mock_response("https://screenplay-fake.mbtace.com/api/pa-messages/changed-interval") do
    response = [
      %{
        "alert_id" => nil,
        "audio_text" =>
          "This is an example of a PA message that will be played at an MBTA station",
        "audio_url" => nil,
        "days_of_week" => [1, 2, 3, 4, 5, 6, 7],
        "end_time" => "2033-12-05T23:53:23Z",
        "id" => 4,
        "inserted_at" => "2024-06-03T18:33:31Z",
        "interval_in_minutes" => 1,
        "message_type" => nil,
        "paused" => nil,
        "priority" => 1,
        "saved" => nil,
        "sign_ids" => [],
        "start_time" => "2024-06-03T18:33:23Z",
        "updated_at" => "2024-06-03T18:33:31Z",
        "visual_text" =>
          "This is an example of a PA message that will be played at an MBTA station"
      },
      %{
        "alert_id" => nil,
        "audio_text" => "This is another PA message that will play at MBTA stations",
        "audio_url" => nil,
        "days_of_week" => [1, 2, 3, 4, 5, 6, 7],
        "end_time" => "2027-08-05T05:41:10Z",
        "id" => 5,
        "inserted_at" => "2024-06-03T19:54:40Z",
        "interval_in_minutes" => 1,
        "message_type" => nil,
        "paused" => nil,
        "priority" => 1,
        "saved" => nil,
        "sign_ids" => [],
        "start_time" => "2024-06-03T19:54:30Z",
        "updated_at" => "2024-06-03T19:54:40Z",
        "visual_text" => "This is another PA message that will play at MBTA stations"
      }
    ]

    {:ok, %Req.Response{status: 200, body: response}}
  end

  def mock_response("fake_trip_update2.json") do
    feed_message =
      %{
        "entity" => [
          %{
            "id" => "1490783458_32568935",
            "trip_update" => %{
              "stop_time_update" => [
                %{
                  "arrival" => %{
                    "time" => 1_491_570_180
                  },
                  "departure" => nil,
                  "stop_id" => "stop_to_update",
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
            }
          }
        ],
        "header" => %{
          "gtfs_realtime_version" => "1.0",
          "incrementality" => "FULL_DATASET",
          "timestamp" => 1_490_783_458
        }
      }

    {:ok,
     %Req.Response{
       status: 200,
       body: feed_message,
       headers: %{"last-modified" => ["Wed, 29 Mar 2017 10:30:58 GMT"]}
     }}
  end

  def mock_response("trip_updates_out_of_service_1") do
    feed_message =
      %{
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
                    "time" => 1_491_570_080
                  },
                  "departure" => nil,
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70263",
                  "stop_sequence" => 2,
                  "stops_away" => 0,
                  "stopped?" => true
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

    {:ok,
     %Req.Response{
       status: 200,
       body: feed_message,
       headers: %{"last-modified" => ["Wed, 29 Mar 2017 10:30:58 GMT"]}
     }}
  end

  def mock_response("vehicle_positions_out_of_service_1") do
    feed_message =
      %{
        "entity" => [
          %{
            "alert" => nil,
            "id" => "1490783458_G-10040",
            "is_deleted" => false,
            "trip_update" => nil,
            "vehicle" => %{
              "congestion_level" => nil,
              "current_status" => "STOPPED_AT",
              "current_stop_sequence" => 2,
              "occupancy_status" => nil,
              "position" => %{
                "bearing" => 315.0,
                "latitude" => 42.33723,
                "longitude" => -71.25208,
                "odometer" => nil,
                "speed" => 4.313936
              },
              "stop_id" => "70263",
              "timestamp" => 1_490_783_458,
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
            }
          }
        ]
      }

    {:ok,
     %Req.Response{
       status: 200,
       body: feed_message,
       headers: %{"last-modified" => ["Wed, 29 Mar 2017 10:30:58 GMT"]}
     }}
  end

  def mock_response("trip_updates_out_of_service_2") do
    feed_message =
      %{
        "entity" => [
          %{
            "alert" => nil,
            "id" => "1490783458_32568937",
            "is_deleted" => false,
            "trip_update" => %{
              "delay" => nil,
              "stop_time_update" => [
                %{
                  "arrival" => nil,
                  "departure" => nil,
                  "schedule_relationship" => "SKIPPED",
                  "stop_id" => "70261",
                  "stop_sequence" => 2,
                  "stops_away" => nil,
                  "stopped?" => true
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
          "timestamp" => 1_490_783_578
        }
      }

    {:ok,
     %Req.Response{
       status: 200,
       body: feed_message,
       headers: %{"last-modified" => ["Wed, 29 Mar 2017 10:32:58 GMT"]}
     }}
  end

  def mock_response("vehicle_positions_out_of_service_2") do
    feed_message =
      %{
        "entity" => [
          %{
            "alert" => nil,
            "id" => "1490783578_G-10040",
            "is_deleted" => false,
            "trip_update" => nil,
            "vehicle" => %{
              "congestion_level" => nil,
              "current_status" => "STOPPED_AT",
              "current_stop_sequence" => 2,
              "occupancy_status" => nil,
              "position" => %{
                "bearing" => 315.0,
                "latitude" => 42.33723,
                "longitude" => -71.25208,
                "odometer" => nil,
                "speed" => 4.313936
              },
              "stop_id" => "70261",
              "timestamp" => 1_490_783_578,
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
            }
          }
        ]
      }

    {:ok,
     %Req.Response{
       status: 200,
       body: feed_message,
       headers: %{"last-modified" => ["Wed, 29 Mar 2017 10:32:58 GMT"]}
     }}
  end

  def mock_response("trip_updates_304") do
    {:ok, %Req.Response{status: 304}}
  end

  def mock_response("vehicle_positions_304") do
    {:ok, %Req.Response{status: 304}}
  end

  def mock_response("trip_updates_error") do
    {:error, %Req.TransportError{reason: :timeout}}
  end

  def mock_response("vehicle_position_error") do
    {:error, %Req.TransportError{reason: :timeout}}
  end

  def mock_response("fake_vehicle_position.json") do
    {:ok, %Req.Response{status: 200, body: %{"entity" => []}}}
  end

  def mock_response(
        "https://api-dev-green.mbtace.com/schedules?filter[stop]=500_error&filter[direction_id]=0,1"
      ) do
    {:ok, %Req.Response{status: 500, body: ""}}
  end

  def mock_response(
        "https://api-dev-green.mbtace.com/schedules?filter[stop]=unknown_error&filter[direction_id]=0,1"
      ) do
    {:error, %Req.HTTPError{reason: :invalid_header}}
  end

  def mock_response(
        "https://api-dev-green.mbtace.com/schedules?filter[stop]=valid_json&filter[direction_id]=0,1"
      ) do
    {:ok, %Req.Response{status: 200, body: %{"data" => [%{"relationships" => "trip"}]}}}
  end

  def mock_response("unknown") do
    {:error, "unknown response"}
  end

  def mock_response("https://api-dev-green.mbtace.com/schedules" <> _) do
    {:ok, %Req.Response{status: 200, body: %{"data" => []}}}
  end

  def mock_response("https://api-dev-green.mbtace.com/alerts") do
    response = %{
      "data" => [
        %{
          "attributes" => %{
            "effect" => "SHUTTLE",
            "informed_entity" => [
              %{
                "stop" => "70151",
                "route" => "Green-B"
              }
            ]
          }
        },
        %{
          "attributes" => %{
            "effect" => "SHUTTLE",
            "informed_entity" => [
              %{
                "stop" => "70151",
                "route" => "Green-B"
              }
            ]
          }
        },
        %{
          "attributes" => %{
            "effect" => "SUSPENSION",
            "informed_entity" => [
              %{
                "route" => "Green-B"
              },
              %{
                "route" => "Green-C"
              },
              %{
                "route" => "Green-D"
              },
              %{
                "route" => "Green-E"
              }
            ]
          }
        },
        %{
          "attributes" => %{
            "effect" => "SUSPENSION",
            "informed_entity" => [
              %{
                "stop" => "70036",
                "route" => "Orange"
              },
              %{
                "stop" => "70034",
                "route" => "Orange"
              },
              %{
                "stop" => "70033",
                "route" => "Orange"
              },
              %{
                "stop" => "70032",
                "route" => "Orange"
              }
            ]
          }
        },
        %{
          "attributes" => %{
            "effect" => "SHUTTLE",
            "informed_entity" => [
              %{
                "route" => "Mattapan"
              }
            ]
          }
        },
        %{
          "attributes" => %{
            "effect" => "STATION_CLOSURE",
            "informed_entity" => [
              %{
                "stop" => "70063",
                "route" => "Red"
              }
            ]
          }
        },
        %{
          "attributes" => %{
            "effect" => "STOP_CLOSURE",
            "informed_entity" => [
              %{
                "stop" => "74636",
                "route" => "743"
              }
            ]
          }
        },
        %{
          "attributes" => %{
            "effect" => "SOMETHING_IRRELEVANT",
            "informed_entity" => [
              %{
                "stop" => "70152",
                "route" => "Green-B"
              }
            ]
          }
        },
        %{
          "attributes" => %{
            "effect" => "SOMETHING_ELSE_IRRELEVANT",
            "informed_entity" => [
              %{
                "route" => "Red"
              }
            ]
          }
        },
        %{
          "attributes" => %{
            "effect" => "YET_ANOTHER_IRRELEVANT_THING",
            "informed_entity" => [
              %{
                "route" => "Blue"
              }
            ]
          }
        },
        %{
          "attributes" => %{
            "effect" => "SUSPENSION",
            "informed_entity" => [
              %{
                "route" => "1"
              }
            ]
          }
        }
      ]
    }

    {:ok, %Req.Response{status: 200, body: response}}
  end

  def mock_response("https://api-dev-green.mbtace.com/predictions" <> _) do
    {:ok, %Req.Response{status: 200, body: %{"data" => [], "included" => []}}}
  end

  def mock_response("https://api-dev-green.mbtace.com/routes" <> _) do
    {:ok, %Req.Response{status: 200, body: %{"data" => []}}}
  end

  def mock_response("https://api-dev-green.mbtace.com/stops" <> _) do
    {:ok, %Req.Response{status: 200, body: %{"data" => []}}}
  end

  def mock_response("https://www.chelseabridgesys.com/api/api/BridgeRealTime" <> _) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{"liftInProgress" => false, "estimatedDurationInMinutes" => 0}
     }}
  end

  def mock_response(_) do
    {:ok, %Req.Response{status: 200, body: ""}}
  end
end
