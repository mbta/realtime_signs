defmodule Sign.Predictions do
  use GenServer
  require Logger

  @vehicle_positions_url "https://s3.amazonaws.com/mbta-gtfs-s3/VehiclePositions.pb"
  @trip_updates_url "https://s3.amazonaws.com/mbta-gtfs-s3/TripUpdates.pb"
  @default_opts [vehicle_positions_url: @vehicle_positions_url, trip_updates_url: @trip_updates_url, name: __MODULE__]

  def start_link(user_opts \\ []) do
    opts = Keyword.merge(@default_opts, user_opts)
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    schedule_download()
    {:ok, Keyword.take(opts, [:vehicle_positions_url, :trip_updates_url])}
  end

  def handle_info(:download, state) do
    vehicle_positions = state[:vehicle_positions_url] |> fetch_pb_file() |> decode_response()
    trip_updates = state[:trip_updates_url] |> fetch_pb_file() |> decode_response()
    current_time = Timex.now()

    Sign.State.update(trip_updates, vehicle_positions, current_time)

    schedule_download()
    {:noreply, state}
  end

  defp schedule_download() do
    Process.send_after(self(), :download, 1 * 1000)
  end

  @spec fetch_pb_file(String.t) :: {:ok, String.t} | {:error, String.t, String.t}
  defp fetch_pb_file(url) do
    http_client = Application.get_env(:realtime_signs, :http_client)
    case http_client.get(url) do
      {:ok, %HTTPoison.Response{body: body, status_code: status}} when status >= 200 and status < 300 ->
        {:ok, body}
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "Status code #{inspect status}", url}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "#{inspect reason}", url}
      _ ->
      {:error, "unknown reason", url}
    end
  end

  @spec decode_response({:ok, String.t} | {:error, String.t, String.t}) :: map
  defp decode_response({:error, reason, url}) do
    Logger.warn("Failed HTTP GET to #{inspect url}: #{inspect reason}")
    %{}
  end
  defp decode_response({:ok, body}) do
    GTFS.Realtime.FeedMessage.decode(body)
  end
end
