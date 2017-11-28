defmodule Fake.HTTPoison do
  def get(url, headers, options \\ []) do
    if options[:stream_to] do
      send options[:stream_to], %HTTPoison.AsyncStatus{code: 200}
      send options[:stream_to], %HTTPoison.AsyncChunk{chunk: "lol"}
      send options[:stream_to], %HTTPoison.AsyncEnd{}
    end
    {url, headers, options}
  end

  def post(url, body, headers \\ []) do
    {url, body, headers}
  end
end
