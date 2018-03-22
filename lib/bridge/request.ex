defmodule Bridge.Request do
  require Logger

  @bridge_url "https://slg.aecomonline.net/api/v1/bridge/1"

  def get_status() do
    headers = [{"Authorization", get_auth_header()}]
    http_client = Application.get_env(:realtime_signs, :http_client)

    @bridge_url
    |> http_client.get(headers)
    |> parse_response()
  end

  defp parse_response({:ok, %HTTPoison.Response{status_code: status, body: body}}) when status >= 200 and status < 300 do
    case Poison.decode(body) do
      {:ok, %{"status" => status}} ->
        status
      _ ->
        Logger.warn("Could not parse json response")
        nil
    end
  end
  defp parse_response({:ok, %HTTPoison.Response{status_code: status}}) do
    Logger.warn("Could not query bridge API: status code #{status}")
    nil
  end
  defp parse_response({:error, %HTTPoison.Error{reason: reason}}) do
    Logger.warn("Could not query bridge API: #{reason}")
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
