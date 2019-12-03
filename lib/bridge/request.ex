defmodule Bridge.Request do
  require Logger

  @bridge_url "https://slg.aecomonline.net/api/v1/lift/findByBridgeId/"

  @spec get_status(non_neg_integer, DateTime.t()) :: {String.t(), non_neg_integer | nil} | nil
  def get_status(id, current_time) do
    headers = [{"Authorization", get_auth_header()}]
    http_client = Application.get_env(:realtime_signs, :http_client)

    @bridge_url
    |> Kernel.<>("#{id}")
    |> http_client.get(headers, timeout: 2000, recv_timeout: 2000, ssl: [versions: [:"tlsv1.2"]])
    |> parse_response(current_time)
  end

  @spec parse_response({:ok | :error, HTTPoison.Response.t()}, DateTime.t()) ::
          {String.t(), non_neg_integer | nil} | nil
  defp parse_response({:ok, %HTTPoison.Response{status_code: status, body: body}}, current_time)
       when status >= 200 and status < 300 do
    case Jason.decode(body) do
      {:ok, response} ->
        do_parse_response(response, current_time)

      _ ->
        Logger.warn("bridge_api_failure: could not parse json response")
        nil
    end
  end

  defp parse_response({:ok, %HTTPoison.Response{status_code: status}}, _current_time) do
    Logger.warn("bridge_api_failure: status code #{inspect(status)}")
    nil
  end

  defp parse_response({:error, %HTTPoison.Error{reason: reason}}, _current_time) do
    Logger.warn("bridge_api_failure: #{inspect(reason)}")
    nil
  end

  defp do_parse_response(response, current_time) do
    status = get_in(response, ["bridge", "bridgeStatusId", "status"])
    estimate_time_string = get_in(response, ["lift_estimate", "estimate_time"])
    duration = get_duration(estimate_time_string, current_time)

    Logger.info(
      "bridge_response status=#{inspect(status)}, estimate_time=#{estimate_time_string}, duration=#{
        inspect(duration)
      }"
    )

    {status, duration}
  end

  def get_duration(estimate_time_string, current_time) do
    estimate_time_string
    |> Timex.parse("{ISO:Extended}")
    |> do_get_duration(current_time)
  end

  defp do_get_duration({:ok, estimate_time}, current_time) do
    time_zone = Application.get_env(:realtime_signs, :time_zone)
    estimate_datetime = Timex.to_datetime(estimate_time, time_zone)
    Timex.diff(estimate_datetime, current_time, :minutes)
  end

  defp do_get_duration(_, _current_time) do
    nil
  end

  defp get_auth_header() do
    username = Application.get_env(:realtime_signs, :bridge_api_username)
    password = Application.get_env(:realtime_signs, :bridge_api_password)
    auth_string = "#{username}:#{password}"
    encoded_auth_string = Base.encode64(auth_string)
    "Basic #{encoded_auth_string}"
  end
end
