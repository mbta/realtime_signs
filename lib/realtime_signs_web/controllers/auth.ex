defmodule RealtimeSignsWeb.Auth do
  @moduledoc "Authenticates API requests using a set of keys defined in the environment."
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    authorized =
      with [key] <- get_req_header(conn, "x-api-key") do
        key == Application.get_env(:realtime_signs, :monitoring_api_key)
      else
        _ ->
          false
      end

    if authorized, do: conn, else: conn |> send_resp(401, "unauthorized") |> halt()
  end
end
