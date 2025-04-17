defmodule Engine.ChelseaBridge do
  use GenServer
  require Logger

  @base_api_url "https://www.chelseabridgesys.com/api/api/"

  @callback bridge_status() :: %{raised: boolean() | nil, estimate: DateTime.t() | nil}
  def bridge_status() do
    case :ets.lookup(:bridge_status, :value) do
      [{:value, data}] -> data
      _ -> %{raised?: nil, estimate: nil}
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    send(self(), :update)
    :ets.new(:bridge_status, [:named_table, read_concurrency: true])
    {:ok, %{}}
  end

  def handle_info(:update, state) do
    Process.send_after(self(), :update, 60_000)
    http_client = Application.get_env(:realtime_signs, :http_client)
    now = Timex.now()

    with {:ok, %{status_code: 200, body: body}} <-
           http_client.get("#{@base_api_url}BridgeRealTime", [
             {"Authorization", "Bearer #{get_cached_or_new_token(now)}"}
           ]),
         {:ok, data} <- Jason.decode(body) do
      # TODO: Estimate maybe should be nil in cases when estimatedDurationInMinutes is 0
      :ets.insert(
        :bridge_status,
        {:value,
         %{
           raised?: Map.get(data, "liftInProgress"),
           estimate: DateTime.add(now, Map.get(data, "estimatedDurationInMinutes"), :minute)
         }}
      )

      {:noreply, state}
    else
      err ->
        Logger.error("Error getting bridge status: #{inspect(err)}")
    end
  end

  def handle_info(msg, state) do
    Logger.warning("Engine.ChelseaBridge unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp get_cached_or_new_token(now) do
    case :ets.lookup(:bridge_status, :auth) do
      [auth: %{access_token: access_token, expiration: expiration}] ->
        # If token found, only return if still before expiration date
        if DateTime.compare(expiration, now) == :gt do
          access_token
        else
          update_api_token(now)
        end

      _ ->
        update_api_token(now)
    end
  end

  def update_api_token(now) do
    # Calls a token granting endpoint with a username and password from our environment variables.
    # This token grants Bridge Data API access, and must be refreshed at least every month
    username = Application.get_env(:realtime_signs, :chelsea_bridge_username)
    password = Application.get_env(:realtime_signs, :chelsea_bridge_password)
    http_poster = Application.get_env(:realtime_signs, :http_poster_mod)

    # Encode as application/x-www-form-urlencoded
    body =
      URI.encode_query(%{
        "grant_type" => "password",
        "username" => username,
        "password" => password
      })

    with {:ok, %{status_code: 200, body: body}} <-
           http_poster.post("#{@base_api_url}token", body, [
             {"Content-Type", "application/x-www-form-urlencoded"}
           ]),
         {:ok, data} <- Jason.decode(body) do
      expiration =
        now
        |> DateTime.add(Map.get(data, "expires_in"), :second)

      :ets.insert(
        :bridge_status,
        {:auth, %{access_token: Map.get(data, "access_token"), expiration: expiration}}
      )

      Map.get(data, "access_token")
    else
      err ->
        Logger.error("Error getting bridge access_token: #{inspect(err)}")
    end
  end
end
