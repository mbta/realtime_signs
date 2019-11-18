defmodule Headway.Request do
  require Logger

  @spec get_schedules([GTFS.station_id()]) :: [%{}] | :error
  def get_schedules(station_ids) do
    http_client = Application.get_env(:realtime_signs, :http_client)
    api_v3_key = Application.get_env(:realtime_signs, :api_v3_key)

    results =
      Enum.group_by(station_ids, &directions_for_station_id/1)
      |> Enum.map(&build_request/1)
      |> Enum.map(
        &http_client.get(&1, api_key_header(api_v3_key), timeout: 5000, recv_timeout: 5000)
      )
      |> Enum.map(&validate_and_parse_response/1)

    if Enum.any?(results, &(&1 == :error)) do
      :error
    else
      Enum.concat(results)
    end
  end

  @spec build_request({[String.t()], [GTFS.station_id()]}) :: String.t()
  def build_request({direction_ids, station_ids}) do
    id_filter = station_ids |> Enum.map(&URI.encode/1) |> Enum.join(",")
    direction_filter = direction_ids |> Enum.map(&URI.encode/1) |> Enum.join(",")
    schedule_api_url = Application.get_env(:realtime_signs, :api_v3_url) <> "/schedules"
    schedule_api_url <> "?filter[stop]=#{id_filter}&filter[direction_id]=#{direction_filter}"
  end

  @spec validate_and_parse_response({atom, %HTTPoison.Response{}} | {atom, %HTTPoison.Error{}}) ::
          [
            map()
          ]
          | :error
  defp validate_and_parse_response(response) do
    case response do
      {:ok, %HTTPoison.Response{status_code: status, body: body}}
      when status >= 200 and status < 300 ->
        parse_body(body)

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.warn(
          "Could not load schedules. Response returned with status code #{inspect(status)}"
        )

        :error

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("Could not load schedules: #{inspect(reason)}")
        :error
    end
  end

  @spec parse_body(String.t()) :: [map()]
  defp parse_body(body) do
    case Poison.decode(body) do
      {:ok, response} ->
        Map.get(response, "data")

      {:error, reason} ->
        Logger.warn("Could not decode response for scheduled headways: #{inspect(reason)}")
        []
    end
  end

  defp api_key_header(nil), do: []
  defp api_key_header(key), do: [{"x-api-key", key}]

  @spec directions_for_station_id(GTFS.station_id()) :: [String.t()]
  defp directions_for_station_id("70061"), do: ["0"]
  defp directions_for_station_id("70036"), do: ["0"]
  defp directions_for_station_id("70105"), do: ["1"]
  defp directions_for_station_id("70001"), do: ["1"]
  defp directions_for_station_id(_), do: ~w[0 1]
end
