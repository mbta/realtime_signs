defmodule Fake.HTTPoison do
  def get(url, headers \\ [], options \\ []) do
    if options[:stream_to] do
      send(options[:stream_to], %HTTPoison.AsyncStatus{code: 200})
      send(options[:stream_to], %HTTPoison.AsyncChunk{chunk: "lol"})
      send(options[:stream_to], %HTTPoison.AsyncEnd{})
    end

    {url, headers, options}
    mock_response(url)
  end

  def post(_url, body, _headers \\ [], _params \\ []) do
    cond do
      body =~ "timeout" ->
        {:error, %HTTPoison.Error{reason: :timeout}}

      body =~ "bad_sign" ->
        {:ok, %HTTPoison.Response{status_code: 404}}

      body =~ "MsgType=SignContent&uid=" ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~ "mid=133&var=5508%2C5512&typ=1&sta=SBOX010000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~
          ~r/MsgType=Canned&uid=[0-9]+&mid=133&var=5508%2C5512&typ=1&sta=SBOX010000&pri=5&tim=60/ ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~
          ~r/MsgType=Canned&uid=[0-9]+&mid=134&var=5508%2C5512&typ=1&sta=SBSQ100000&pri=5&tim=60/ ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~ ~r/MsgType=Canned&uid=[0-9]+&mid=135&var=5510&typ=0&sta=SCHS000001&pri=5&tim=200/ ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~
          ~r/MsgType=Canned&uid=[0-9]+&mid=150&var=37008%2C37014&typ=1&sta=SBOX000010&pri=5&tim=60/ ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~
          ~r/MsgType=Canned&uid=[0-9]+&mid=90&var=4016%2C503%2C5004&typ=1&sta=MCED001000&pri=5&tim=60/ ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~
          ~r/MsgType=Canned&uid=[0-9]+&mid=103&var=90128&typ=0&sta=MCED000100&pri=5&tim=60/ ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~ ~r/MsgType=Canned&uid=[0-9]+&mid=103&var=90129&typ=0&sta=MCAP001000&pri=5&tim=60/ ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~ ~r/MsgType=AdHoc&uid=[0-9]+&msg=Custom\+Message&typ=1&sta=MCAP001000&pri=5&tim=60/ ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~
          ~r/MsgType=AdHoc&uid=[0-9]+&msg=Custom\+Orange\+Line\+Message&typ=1&sta=MCAP001000&pri=5&tim=60/ ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~ "grant_type" ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{"access_token" => "test_access_token", "expires_in" => 2_591_999})
         }}
    end
  end

  @spec mock_response(String.t()) :: {:ok, %HTTPoison.Response{}} | {:error, %HTTPoison.Error{}}
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
      |> Jason.encode!()

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: feed_message,
       headers: [{"Last-Modified", "Wed, 29 Mar 2017 10:30:58 GMT"}]
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

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(response)}}
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

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(response)}}
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

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(response)}}
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
      |> Jason.encode!()

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: feed_message,
       headers: [{"Last-Modified", "Wed, 29 Mar 2017 10:30:58 GMT"}]
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
      |> Jason.encode!()

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: feed_message,
       headers: [{"Last-Modified", "Wed, 29 Mar 2017 10:30:58 GMT"}]
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
      |> Jason.encode!()

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: feed_message,
       headers: [{"Last-Modified", "Wed, 29 Mar 2017 10:30:58 GMT"}]
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
      |> Jason.encode!()

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: feed_message,
       headers: [{"Last-Modified", "Wed, 29 Mar 2017 10:32:58 GMT"}]
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
      |> Jason.encode!()

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: feed_message,
       headers: [{"Last-Modified", "Wed, 29 Mar 2017 10:32:58 GMT"}]
     }}
  end

  def mock_response("trip_updates_304") do
    {:ok, %HTTPoison.Response{status_code: 304}}
  end

  def mock_response("vehicle_positions_304") do
    {:ok, %HTTPoison.Response{status_code: 304}}
  end

  def mock_response("trip_updates_error") do
    {:error, %HTTPoison.Error{reason: :timeout}}
  end

  def mock_response("vehicle_position_error") do
    {:error, %HTTPoison.Error{reason: :timeout}}
  end

  def mock_response(
        "https://api-dev-green.mbtace.com/schedules?filter[stop]=500_error&filter[direction_id]=0,1"
      ) do
    {:ok, %HTTPoison.Response{status_code: 500, body: ""}}
  end

  def mock_response(
        "https://api-dev-green.mbtace.com/schedules?filter[stop]=unknown_error&filter[direction_id]=0,1"
      ) do
    {:error, %HTTPoison.Error{reason: "Bad URL"}}
  end

  def mock_response(
        "https://api-dev-green.mbtace.com/schedules?filter[stop]=parse_error&filter[direction_id]=0,1"
      ) do
    {:ok, %HTTPoison.Response{status_code: 200, body: "BAD JSON"}}
  end

  def mock_response(
        "https://api-dev-green.mbtace.com/schedules?filter[stop]=valid_json&filter[direction_id]=0,1"
      ) do
    json = %{"data" => [%{"relationships" => "trip"}]}
    encoded = Jason.encode!(json)
    {:ok, %HTTPoison.Response{status_code: 200, body: encoded}}
  end

  def mock_response("unknown") do
    {:error, "unknown response"}
  end

  def mock_response("https://api-dev-green.mbtace.com/schedules" <> _) do
    json = %{"data" => []}
    encoded = Jason.encode!(json)
    {:ok, %HTTPoison.Response{status_code: 200, body: encoded}}
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

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(response)}}
  end

  def mock_response("https://api-dev-green.mbtace.com/predictions" <> _) do
    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{data: [], included: []})}}
  end

  def mock_response("https://api-dev-green.mbtace.com/routes" <> _) do
    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{data: []})}}
  end

  def mock_response("https://www.chelseabridgesys.com/api/api/BridgeRealTime" <> _) do
    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: Jason.encode!(%{"liftInProgress" => false, "estimatedDurationInMinutes" => 0})
     }}
  end

  def mock_response(_) do
    {:ok, %HTTPoison.Response{status_code: 200, body: ""}}
  end
end
