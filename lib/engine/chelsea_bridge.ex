defmodule Engine.ChelseaBridge do
  use GenServer
  require Logger

  alias Signs.Utilities.EtsUtils

  # API constants
  @base_api_url "https://www.chelseabridgesys.com/api/api/"
  @api_status_endpoint "BridgeRealTime"
  @api_token_endpoint "token"

  @bridge_table_name :bridge_status

  @type token :: %{
          value: String.t() | nil,
          expiration: DateTime.t() | nil
        }

  @type state :: %{
          table: :ets.tab(),
          token: token
        }

  @callback bridge_status() :: %{raised: boolean() | nil, estimate: DateTime.t() | nil}
  def bridge_status(ets_table_name \\ @bridge_table_name) do
    case :ets.lookup(ets_table_name, :value) do
      [{:value, data}] -> data
      _ -> %{raised?: nil, estimate: nil}
    end
  end

  def start_link(opts \\ []) do
    name = opts[:gen_server_name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    bridge_ets_table =
      :ets.new(opts[:bridge_ets_table_name] || @bridge_table_name, [
        :named_table,
        read_concurrency: true
      ])

    state = %{
      table: bridge_ets_table,
      token: %{value: nil, expiration: nil}
    }

    send(self(), :update)

    {:ok, state}
  end

  def handle_info(:update, state) do
    Process.send_after(self(), :update, 60_000)
    http_client = Application.get_env(:realtime_signs, :http_client)
    now = Timex.now()

    token =
      if(state.token.expiration == nil or DateTime.compare(state.token.expiration, now) == :lt) do
        update_api_token(now)
      else
        state.token
      end

    with {:ok, %{status_code: 200, body: body}} <-
           http_client.get("#{@base_api_url}#{@api_status_endpoint}", [
             {"Authorization", "Bearer #{token.value}"}
           ]),
         {:ok, data} <- Jason.decode(body) do
      EtsUtils.write_ets(
        state.table,
        %{
          :value => %{
            raised?: Map.get(data, "liftInProgress"),
            estimate: DateTime.add(now, Map.get(data, "estimatedDurationInMinutes"), :minute)
          }
        },
        :none
      )

      {:noreply, %{state | token: token}}
    else
      err ->
        Logger.error("Error getting bridge status: #{inspect(err)}")
    end
  end

  def handle_info(msg, state) do
    Logger.warning("Engine.ChelseaBridge unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end

  @spec update_api_token(DateTime.t()) :: token
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
           http_poster.post("#{@base_api_url}#{@api_token_endpoint}", body, [
             {"Content-Type", "application/x-www-form-urlencoded"}
           ]),
         {:ok, data} <- Jason.decode(body) do
      expiration =
        now
        |> DateTime.add(Map.get(data, "expires_in"), :second)

      %{
        value: Map.get(data, "access_token"),
        expiration: expiration
      }
    else
      err ->
        Logger.error("Error getting bridge access_token: #{inspect(err)}")
    end
  end
end
