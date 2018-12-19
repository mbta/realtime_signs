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
    end
  end

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
      |> Poison.encode!()

    {:ok, %HTTPoison.Response{status_code: 200, body: feed_message}}
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

  def mock_response("https://green.dev.api.mbtace.com/schedules?filter[stop]=500_error") do
    {:ok, %HTTPoison.Response{status_code: 500, body: ""}}
  end

  def mock_response("https://green.dev.api.mbtace.com/schedules?filter[stop]=unknown_error") do
    {:error, %HTTPoison.Error{reason: "Bad URL"}}
  end

  def mock_response("https://green.dev.api.mbtace.com/schedules?filter[stop]=parse_error") do
    {:ok, %HTTPoison.Response{status_code: 200, body: "BAD JSON"}}
  end

  def mock_response("https://green.dev.api.mbtace.com/schedules?filter[stop]=valid_json") do
    json = %{"data" => [%{"relationships" => "trip"}]}
    encoded = Poison.encode!(json)
    {:ok, %HTTPoison.Response{status_code: 200, body: encoded}}
  end

  def mock_response("unknown") do
    {:error, "unknown response"}
  end

  def mock_response("https://slg.aecomonline.net/api/v1/lift/findByBridgeId/1") do
    estimate = "2000-01-23T04:56:07.000+00:00"

    json = %{
      "bridge" => %{"bridgeStatusId" => %{"status" => "Raised"}},
      "lift_estimate" => %{"estimate_time" => estimate}
    }

    encoded = Poison.encode!(json)
    {:ok, %HTTPoison.Response{status_code: 200, body: encoded}}
  end

  def mock_response("https://slg.aecomonline.net/api/v1/lift/findByBridgeId/500") do
    {:ok, %HTTPoison.Response{status_code: 500}}
  end

  def mock_response("https://slg.aecomonline.net/api/v1/lift/findByBridgeId/754") do
    {:error, %HTTPoison.Error{reason: "Unknown error"}}
  end

  def mock_response("https://slg.aecomonline.net/api/v1/lift/findByBridgeId/201") do
    {:ok, %HTTPoison.Response{status_code: 201, body: "BAD JSON"}}
  end

  def mock_response("https://green.dev.api.mbtace.com/schedules" <> _) do
    json = %{"data" => []}
    encoded = Poison.encode!(json)
    {:ok, %HTTPoison.Response{status_code: 200, body: encoded}}
  end

  def mock_response("https://green.dev.api.mbtace.com/alerts") do
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
            "effect" => "SOMETHING_IRRELEVANT",
            "informed_entity" => [
              %{
                "stop" => "70152"
              }
            ]
          }
        }
      ]
    }

    {:ok, %HTTPoison.Response{status_code: 200, body: Poison.encode!(response)}}
  end

  def mock_response(_), do: {:ok, %HTTPoison.Response{status_code: 200, body: ""}}
end
