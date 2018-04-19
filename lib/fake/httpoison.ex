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

  def post(_url, body, _headers \\ []) do
    cond do
      body =~ "uid=11" ->
        {:ok, %HTTPoison.Response{status_code: 500}}
      body =~ "uid=12" ->
        {:error, %HTTPoison.Error{reason: :timeout}}
      true ->
        {:ok, %HTTPoison.Response{status_code: 200}}
    end
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
    estimate = "2000-01-23T04:56:07.000+00:00"
    json = %{"bridge" => %{"bridgeStatusId" => %{"status" => "Raised"}}, "lift_estimate" => %{"estimate_time" => estimate}}
    encoded = Poison.encode!(json)
    {:ok, %HTTPoison.Response{status_code: 200, body: encoded}}
  end
  def mock_response("https://slg.aecomonline.net/api/v1/lift/findByBridgeId/2") do
    json = %{"bridge" => %{"bridgeStatusId" => %{"status" => "Raised"}}, "lift_estimate" => %{"estimate_time" => "bad_time"}}
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
