defmodule Sign.Updater do
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    {uid, opts} = Keyword.pop_first(opts, :uid, System.system_time(:second))
    GenServer.start_link(__MODULE__, uid, opts)
  end

  def host, do: Application.get_env(:realtime_signs, :sign_head_end_host)
  def url, do: "http://#{host()}/mbta/cgi-bin/RemoteMsgsCgi.exe"

  def request(pid \\ __MODULE__, payload, current_time) do
    GenServer.cast(pid, {:request, payload, current_time})
  end

  def handle_cast({:request, payload, current_time}, uid) do
    send_request(payload, current_time, uid)
    {:noreply, uid + 1}
  end

  def send_request(payload, current_time, uid) do
    command = payload
    |> Sign.Command.to_command
    |> List.insert_at(1, {:uid, uid + 1}) # Ensure that UID comes second in the list (after MsgType)
    |> URI.encode_query
    |> log_sign_update(current_time)

    case http_client().post(url(), command, [{"Content-type", "application/x-www-form-urlencoded"}]) do
      {:ok, %HTTPoison.Response{status_code: status}} when status >= 200 and status < 300 ->
        nil
      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.warn("head_end_post_error: response had status code: #{inspect status}")
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("head_end_post_error: #{inspect reason}")
    end
  end

  defp http_client, do: Application.get_env(:realtime_signs, :http_client)

  defp log_sign_update(command, current_time) do
    Logger.info("Sign.Updater.send_request: #{command}")
    date_str =
      current_time
      |> RTR.Utilities.Time.get_service_date
      |> Timex.format!("%Y%m%d", :strftime)
    time_str = Timex.format!(current_time, "%H:%M:%S", :strftime)
    log_dir = Application.get_env(:realtime_signs, :posts_log_dir)
    path = Path.join(log_dir, "#{date_str}.txt")
    File.write(path, "#{time_str},#{command}\n", [:append, :utf8])
    command
  end
end
