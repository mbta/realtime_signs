defmodule Fake.HTTPoison do
  def get(url, headers, options \\ []) do
    if options[:stream_to] do
      send options[:stream_to], %HTTPoison.AsyncStatus{code: 200}
      send options[:stream_to], %HTTPoison.AsyncChunk{chunk: "lol"}
      send options[:stream_to], %HTTPoison.AsyncEnd{}
    end
    {url, headers, options}
    mock_response(url)
  end

  def post(url, body, headers \\ []) do
    {url, body, headers}
  end

  def mock_response("https://api-v3.mbta.com/schedules" <> _) do
    json = %{"data" => []}
    encoded = Poison.encode!(json)
    {:ok, %HTTPoison.Response{body: encoded}}
  end
  def mock_response(_), do: {:ok, %HTTPoison.Response{body: ""}}
end
