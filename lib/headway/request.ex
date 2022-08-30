defmodule Headway.Request do
  require Logger

  @spec get_schedules([GTFS.station_id()]) :: [%{}] | :error
  def get_schedules(station_ids) do
    api_v3_key = Application.get_env(:realtime_signs, :api_v3_key)

    headers = api_key_header(api_v3_key)

    opts = [
      pool_timeout: 5000,
      receive_timeout: 5000
    ]

    results =
      Enum.group_by(station_ids, &directions_for_station_id/1)
      |> Enum.map(fn direction_and_station_ids ->
        build_request(direction_and_station_ids, headers, opts)
      end)
      |> Enum.map(fn request -> Finch.request(request, HttpClient) end)
      |> Enum.map(&validate_and_parse_response/1)

    if Enum.any?(results, &(&1 == :error)) do
      :error
    else
      Enum.concat(results)
    end
  end

  @spec build_request({[String.t()], [GTFS.station_id()]}, List.t(), List.t()) ::
          Finch.Request.t()
  def build_request({direction_ids, station_ids}, headers, opts) do
    id_filter = station_ids |> Enum.map(&URI.encode/1) |> Enum.join(",")
    direction_filter = direction_ids |> Enum.map(&URI.encode/1) |> Enum.join(",")
    schedule_api_url = Application.get_env(:realtime_signs, :api_v3_url) <> "/schedules"
    schedule_api_url <> "?filter[stop]=#{id_filter}&filter[direction_id]=#{direction_filter}"
    Finch.build(:get, schedule_api_url, headers, "", opts)
  end

  @spec validate_and_parse_response({atom, %HTTPoison.Response{}} | {atom, %HTTPoison.Error{}}) ::
          [
            map()
          ]
          | :error
  defp validate_and_parse_response(response) do
    case response do
      {:ok, %Finch.Response{status: status, body: body}}
      when status >= 200 and status < 300 ->
        parse_body(body)

      {:ok, %Finch.Response{status: status}} ->
        Logger.warn(
          "Could not load schedules. Response returned with status code #{inspect(status)}"
        )

        :error

      {:error, exception} ->
        Logger.warn("Could not load schedules: #{inspect(exception.reason)}")
        :error
    end
  end

  @spec parse_body(String.t()) :: [map()]
  defp parse_body(body) do
    case Jason.decode(body) do
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
