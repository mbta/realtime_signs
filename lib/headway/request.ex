defmodule Headway.Request do
  require Logger
  alias Headway.ScheduleHeadway

  def get_schedules(station_ids) do
    case do_get_schedules(station_ids) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status >= 200 and status < 300 ->
        parse_body(body)
      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.warn("Could not load schedules. Response returned with status code #{inspect status}")
        []
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("Could not load schedules: #{inspect reason}")
        []
    end
  end

  defp do_get_schedules(station_ids) do
    http_client = Application.get_env(:realtime_signs, :http_client)
    station_ids
    |> ScheduleHeadway.build_request()
    |> http_client.get([], [timeout: 2000, recv_timeout: 2000])
  end

  defp parse_body(body) do
    case Poison.decode(body) do
      {:ok, response} ->
        Map.get(response, "data")
      {:error, reason} ->
        Logger.warn("Could not decode response: #{inspect reason}")
        []
    end
  end
end
