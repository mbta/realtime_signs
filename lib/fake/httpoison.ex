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

      body =~ "uid=11" ->
        {:ok, %HTTPoison.Response{status_code: 500}}

      body =~ "uid=12" ->
        {:error, %HTTPoison.Error{reason: :timeout}}

      body =~ "MsgType=SignContent&uid=" ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~ "mid=133&var=5508%2C5512&typ=1&sta=SBOX010000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~ "MsgType=Canned&uid=1000&mid=133&var=5508%2C5512&typ=1&sta=SBOX010000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~ "MsgType=Canned&uid=1001&mid=134&var=5508%2C5512&typ=1&sta=SBSQ100000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~ "MsgType=Canned&uid=1002&mid=135&var=5510&typ=0&sta=SCHS000001&pri=5&tim=200" ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~
          "MsgType=Canned&uid=1003&mid=150&var=37008%2C37014&typ=1&sta=SBOX000010&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~
          "MsgType=Canned&uid=1004&mid=90&var=4016%2C503%2C5004&typ=1&sta=MCED001000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~ "MsgType=Canned&uid=1005&mid=90128&var=&typ=0&sta=MCED000100&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~ "MsgType=Canned&uid=1006&mid=90129&var=&typ=0&sta=MCAP001000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~ "MsgType=AdHoc&uid=1006&msg=Custom+Message&typ=1&sta=MCAP001000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}

      body =~
          "MsgType=AdHoc&uid=1006&msg=Custom+Orange+Line+Message&typ=1&sta=MCAP001000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}
    end
  end

  @spec mock_response(String.t()) :: {:ok, %HTTPoison.Response{}} | {:error, %HTTPoison.Error{}}
  def mock_response("https://fake_update/mbta-gtfs-s3/fake_trip_update.json") do
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
                    "time" => 1_491_570_120,
                    "uncertainty" => nil
                  },
                  "departure" => nil,
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "70263",
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

  def mock_response("fake_trip_update2.json") do
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
                    "time" => 1_491_570_180,
                    "uncertainty" => nil
                  },
                  "departure" => nil,
                  "schedule_relationship" => "SCHEDULED",
                  "stop_id" => "stop_to_update",
                  "stop_sequence" => 1,
                  "stops_away" => 0
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
                    "time" => 1_491_570_080,
                    "uncertainty" => nil
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
                "consist" => [
                  %{
                    "label" => "3260"
                  }
                ],
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
                  "passthrough_time" => 1_491_570_180,
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
                "consist" => [
                  %{
                    "label" => "3260"
                  }
                ],
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
                "route" => "Red"
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
        }
      ]
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(response)}}
  end

  def mock_response(_), do: {:ok, %HTTPoison.Response{status_code: 200, body: ""}}
end
