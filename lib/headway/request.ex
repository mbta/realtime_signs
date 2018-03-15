defmodule Headway.Request do
  require Logger
  alias Headway.ScheduleHeadway

  def get_schedules(station_ids) do
    case do_get_schedules(station_ids) do
      {:ok, %HTTPoison.Response{body: body}} ->
        parse_body(body)
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("Could not load schedules: #{inspect reason}")
        %{}
    end
  end

  defp do_get_schedules(station_ids) do
    station_ids
    |> ScheduleHeadway.build_request()
    |> HTTPoison.get()
  end

  defp parse_body(body) do
    case Poison.decode(body) do
      {:ok, response} ->
        Map.get(response, "data")
      {:error, reason} ->
        Logger.warn("Could not decode response: #{inspect reason}")
        %{}
    end
  end
end
