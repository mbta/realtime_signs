defmodule Headway.Request do
  require Logger
  alias Headway.ScheduleHeadway

  @spec get_schedules([GTFS.station_id()]) :: [%{}]
  def get_schedules(station_ids) do
    http_client = Application.get_env(:realtime_signs, :http_client)
    api_v3_key = Application.get_env(:realtime_signs, :api_v3_key)

    Enum.group_by(station_ids, &directions_for_station_id/1)
    |> Enum.map(&ScheduleHeadway.build_request/1)
    |> Enum.map(
      &http_client.get(&1, api_key_header(api_v3_key), timeout: 2000, recv_timeout: 2000)
    )
    |> Enum.map(&validate_and_parse_response/1)
    |> Enum.concat()
  end

  @spec validate_and_parse_response({atom, %HTTPoison.Response{}} | {atom, %HTTPoison.Error{}}) ::
          [
            %{}
          ]
  defp validate_and_parse_response(response) do
    case response do
      {:ok, %HTTPoison.Response{status_code: status, body: body}}
      when status >= 200 and status < 300 ->
        parse_body(body)

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.warn(
          "Could not load schedules. Response returned with status code #{inspect(status)}"
        )

        []

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("Could not load schedules: #{inspect(reason)}")
        []
    end
  end

  defp parse_body(body) do
    case Poison.decode(body) do
      {:ok, response} ->
        Map.get(response, "data")

      {:error, reason} ->
        Logger.warn("Could not decode response: #{inspect(reason)}")
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
