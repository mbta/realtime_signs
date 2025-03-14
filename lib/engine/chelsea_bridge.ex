defmodule Engine.ChelseaBridge do
  use GenServer
  require Logger

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
    url = Application.get_env(:realtime_signs, :chelsea_bridge_url)
    auth = Application.get_env(:realtime_signs, :chelsea_bridge_auth)
    http_client = Application.get_env(:realtime_signs, :http_client)

    with {:ok, %{status_code: 200, body: body}} <-
           http_client.get(url, [{"Authorization", "Basic #{auth}"}]),
         {:ok, data} <- Jason.decode(body),
         %{"bridge" => %{"bridgeStatusId" => %{"status" => status}}} <- data do
      estimate =
        case data do
          %{"lift_estimate" => %{"estimate_time" => estimate}} ->
            String.replace(estimate, ~r/\.\d+$/, "")
            |> Timex.parse!("{YYYY}-{M}-{D} {h24}:{m}:{s}")
            |> DateTime.from_naive!("America/New_York")

          _ ->
            nil
        end

      :ets.insert(:bridge_status, {:value, %{raised?: status == "Raised", estimate: estimate}})
    else
      err ->
        Logger.error("Error getting bridge status: #{inspect(err)}")
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warning("Engine.ChelseaBridge unknown_message: #{inspect(msg)}")
    {:noreply, state}
  end
end
