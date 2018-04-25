defmodule Fake.HTTPoison do
  def get(url, headers \\ [], options \\ []) do
    if options[:stream_to] do
      send options[:stream_to], %HTTPoison.AsyncStatus{code: 200}
      send options[:stream_to], %HTTPoison.AsyncChunk{chunk: "lol"}
      send options[:stream_to], %HTTPoison.AsyncEnd{}
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
      body =~ "MsgType=Canned&uid=0&mid=133&var=5508%2C5512&typ=1&sta=SBOX010000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}
      body =~ "MsgType=Canned&uid=1000&mid=133&var=5508%2C5512&typ=1&sta=SBOX010000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}
      body =~ "MsgType=Canned&uid=1001&mid=134&var=5508%2C5512&typ=2&sta=SBSQ100000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}
      body =~ "MsgType=Canned&uid=1002&mid=135&var=5510&typ=0&sta=SCHS000001&pri=5&tim=200" ->
        {:ok, %HTTPoison.Response{status_code: 200}}
      body =~ "MsgType=Canned&uid=1003&mid=150&var=37008%2C37014&typ=1&sta=SBOX000010&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}
      body =~ "MsgType=Canned&uid=1004&mid=90&var=4016%2C503%2C5004&typ=1&sta=MCED001000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}
      body =~ "MsgType=Canned&uid=1005&mid=90128&var=&typ=1&sta=MCED000100&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}
      body =~ "MsgType=Canned&uid=1006&mid=90129&var=&typ=1&sta=MCAP001000&pri=5&tim=60" ->
        {:ok, %HTTPoison.Response{status_code: 200}}
    end
  end

  def mock_response("https://fake_update/mbta-gtfs-s3/fake_trip_update.pb") do
    feed_message = %GTFS.Realtime.FeedMessage{entity: [%GTFS.Realtime.FeedEntity{alert: nil,
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
      |> GTFS.Realtime.FeedMessage.encode()

      {:ok, %HTTPoison.Response{status_code: 200, body: feed_message}}
  end
  def mock_response("trip_updates_304") do
    {:ok, %HTTPoison.Response{status_code: 304}}
  end
  def mock_response("https://api-v3.mbta.com/schedules?filter[stop]=500_error") do
    {:ok, %HTTPoison.Response{status_code: 500, body: ""}}
  end
  def mock_response("https://api-v3.mbta.com/schedules?filter[stop]=unknown_error") do
    {:error, %HTTPoison.Error{reason: "Bad URL"}}
  end
  def mock_response("https://api-v3.mbta.com/schedules?filter[stop]=parse_error") do
    {:ok, %HTTPoison.Response{status_code: 200, body: "BAD JSON"}}
  end
  def mock_response("https://api-v3.mbta.com/schedules?filter[stop]=valid_json") do
    json = %{"data" => [%{"relationships" => "trip"}]}
    encoded = Poison.encode!(json)
    {:ok, %HTTPoison.Response{status_code: 200, body: encoded}}
  end
  def mock_response("unknown") do
    {:error, "unknown response"}
  end
  def mock_response("https://slg.aecomonline.net/api/v1/lift/findByBridgeId/1") do
    json = %{"bridge" => %{"bridgeStatusId" => %{"status" => "Raised"}}, "lift_estimate" => %{"duration" => 5}}
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
  def mock_response("https://api-v3.mbta.com/schedules" <> _) do
    json = %{"data" => []}
    encoded = Poison.encode!(json)
    {:ok, %HTTPoison.Response{status_code: 200, body: encoded}}
  end
  def mock_response(_), do: {:ok, %HTTPoison.Response{status_code: 200, body: ""}}
end
