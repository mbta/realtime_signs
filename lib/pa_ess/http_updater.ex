defmodule PaEss.HttpUpdater do
  @moduledoc """
  Fetches from the MessageQueue messages from the various signs, and serializes and POSTs
  them to the PA/ESS head-end server.
  """

  @type t :: %{
    http_poster: module(),
    queue_mod: module(),
    uid: integer()
  }

  @max_send_rate_per_sec 8
  @avg_ms_between_sends round(1000 / @max_send_rate_per_sec)

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    http_poster = opts[:http_poster] || Application.get_env(:realtime_signs, :http_poster_mod)
    queue_mod = opts[:queue_mod] || MessageQueue
    GenServer.start_link(__MODULE__, [http_poster: http_poster, queue_mod: queue_mod], name: __MODULE__)
  end

  def init(opts) do
    schedule_check_queue(self(), 30)
    {:ok, %{http_poster: opts[:http_poster], queue_mod: opts[:queue_mod], uid: 0}}
  end

  def handle_info(:check_queue, state) do
    before_time = System.monotonic_time(:millisecond)

    if (item = state.queue_mod.get_message()) do
      process(item, state)
    end

    send_time = System.monotonic_time(:millisecond) - before_time
    wait_time = max(0, @avg_ms_between_sends - send_time)
    schedule_check_queue(self(), wait_time)

    {:noreply, %{state | uid: state.uid + 1}}
  end

  def process({:update_single_line, [{station, zone}, line_no, msg, duration, start_secs]}, state) do
    cmd = "#{start_display(start_secs)}e#{duration}~#{zone}#{line_no}-#{message_display(msg)}"
    encoded = URI.encode_query([MsgType: "SignContent", uid: state.uid, sta: station, c: cmd])
    Logger.info(["update_single_line: ", encoded])

    update_ui(state.http_poster, encoded)
    send_post(state.http_poster, encoded)
  end
  def process({:update_sign, [{station, zone}, top_line, bottom_line, duration, start_secs]}, state) do
    top_cmd = "#{start_display(start_secs)}e#{duration}~#{zone}1-#{message_display(top_line)}"
    bottom_cmd = "#{start_display(start_secs)}e#{duration}~#{zone}2-#{message_display(bottom_line)}"
    encoded = URI.encode_query([MsgType: "SignContent", uid: state.uid, sta: station, c: top_cmd, c: bottom_cmd])
    Logger.info(["update_sign: ", encoded])

    update_ui(state.http_poster, encoded)
    send_post(state.http_poster, encoded)
  end
  def process({:send_audio, [{station, zone}, audio, priority, timeout]}, state) do
    {message_id, vars, type} = Content.Audio.to_params(audio)

    encoded = [
      MsgType: "Canned",
      uid: state.uid,
      mid: message_id,
      var: Enum.join(vars, ","),
      typ: audio_type(type),
      sta: "#{station}#{zone_bitmap(zone)}",
      pri: priority,
      tim: timeout,
    ]
    |> URI.encode_query
    Logger.info(["send_audio: ", encoded])

    send_post(state.http_poster, encoded)
  end

  defp sign_host, do: Application.get_env(:realtime_signs, :sign_head_end_host)
  defp sign_url, do: "http://#{sign_host()}/mbta/cgi-bin/RemoteMsgsCgi.exe"
  defp sign_ui_host, do: Application.get_env(:realtime_signs, :sign_ui_url)
  defp sign_ui_url, do: "http://#{sign_ui_host()}/messages"

  defp start_display(:now), do: ""
  defp start_display(seconds_from_midnight), do: "t#{seconds_from_midnight}"

  defp message_display(msg) when is_atom(msg), do: "#{msg}"
  defp message_display(msg) when is_map(msg), do: ~s("#{Content.Message.to_string(msg)}")

  # bitmap representing zone: m c n s e w
  defp zone_bitmap("m"), do: "100000"
  defp zone_bitmap("c"), do: "010000"
  defp zone_bitmap("n"), do: "001000"
  defp zone_bitmap("s"), do: "000100"
  defp zone_bitmap("e"), do: "000010"
  defp zone_bitmap("w"), do: "000001"

  defp audio_type(:audio_visual), do: "0"
  defp audio_type(:audio), do: "1"
  defp audio_type(:visual), do: "2"

  defp send_post(http_poster, query) do
    case http_poster.post(sign_url(), query, [{"Content-type", "application/x-www-form-urlencoded"}]) do
      {:ok, %HTTPoison.Response{status_code: status}} when status >= 200 and status < 300 ->
        {:ok, :sent}
      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.warn("head_end_post_error: response had status code: #{inspect status}")
        {:error, :bad_status}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("head_end_post_error: #{inspect reason}")
        {:error, :post_error}
    end
  end

  def update_ui(pid \\ __MODULE__, http_poster, query) do
    key = Application.get_env(:realtime_signs, :sign_ui_api_key)
    case http_poster.post(sign_ui_url(), query, [{"Content-type", "application/x-www-form-urlencoded"}, {"x-api-key", key}]) do
      {:ok, %HTTPoison.Response{status_code: status}} when status == 201 ->
        {:ok, :sent}
      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.warn("sign_ui_post_error: response had status code: #{inspect status}")
        {:error, :bad_status}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("sign_ui_post_error: #{inspect reason}")
        {:error, :post_error}
    end
  end

  defp schedule_check_queue(pid, ms) do
    Process.send_after(pid, :check_queue, ms)
  end
end
