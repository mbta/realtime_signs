defmodule Headway.ObservedHeadwayFetcher do
  require Logger

  @spec fetch() :: {:ok, map()} | :error
  def fetch() do
    http_client = Application.get_env(:realtime_signs, :http_client)
    url = Application.get_env(:realtime_signs, :recent_headways_url)

    case http_client.get(url) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}}
      when status >= 200 and status < 300 ->
        parse_body(body)

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.warn(
          "Could not load recent observed headways. Response returned with status code #{
            inspect(status)
          }"
        )

        :error

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("Could not load recent observed headways: #{inspect(reason)}")
        :error
    end
  end

  @spec parse_body(String.t()) :: {:ok, map()} | :error
  defp parse_body(body) do
    case Poison.decode(body) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        Logger.warn("Could not decode response for observed headways: #{inspect(reason)}")
        :error
    end
  end
end
