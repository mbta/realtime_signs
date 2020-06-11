defmodule PaEss.HttpUpdater do
  use Bitwise

  @moduledoc """
  Fetches from the MessageQueue messages from the various signs, and serializes and POSTs
  them to the PA/ESS head-end server.
  """

  @type t :: %{
          http_poster: module(),
          queue_mod: module(),
          uid: integer()
        }
  @type post_result ::
          {:ok, :sent} | {:ok, :no_audio} | {:error, :bad_status} | {:error, :post_error}

  # Normally an anti-pattern! But we mix compile --force with every deploy
  @max_send_rate_per_sec (32 / Application.get_env(:realtime_signs, :number_of_http_updaters))
                         |> Float.ceil()
                         |> Kernel.trunc()
  @avg_ms_between_sends round(1000 / @max_send_rate_per_sec)

  use GenServer
  require Logger

  def child_spec(nth) do
    %{
      id: :"http_updater#{nth}",
      start: {__MODULE__, :start_link, []}
    }
  end

  def start_link(opts \\ []) do
    http_poster = opts[:http_poster] || Application.get_env(:realtime_signs, :http_poster_mod)
    queue_mod = opts[:queue_mod] || MessageQueue

    GenServer.start_link(
      __MODULE__,
      http_poster: http_poster,
      queue_mod: queue_mod
    )
  end

  def init(opts) do
    schedule_check_queue(self(), 30)
    {:ok, %{http_poster: opts[:http_poster], queue_mod: opts[:queue_mod], uid: 0}}
  end

  def handle_info(:check_queue, state) do
    before_time = System.monotonic_time(:millisecond)

    if item = state.queue_mod.get_message() do
      process(item, state)
    end

    send_time = System.monotonic_time(:millisecond) - before_time
    wait_time = max(0, @avg_ms_between_sends - send_time)
    schedule_check_queue(self(), wait_time)

    {:noreply, %{state | uid: state.uid + 1}}
  end

  @spec process({atom, [any]}, __MODULE__.t()) :: post_result
  def process({:update_single_line, [{station, zone}, line_no, msg, duration, start_secs]}, state) do
    cmd = to_command(msg, duration, start_secs, zone, line_no)
    encoded = URI.encode_query(MsgType: "SignContent", uid: state.uid, sta: station, c: cmd)

    {arinc_time, result} = :timer.tc(fn -> send_post(state.http_poster, encoded) end)

    case result do
      {:ok, _} ->
        {ui_time, _} = :timer.tc(fn -> update_ui(state.http_poster, encoded) end)

        Logger.info([
          "update_single_line: ",
          encoded,
          " pid=",
          inspect(self()),
          " arinc_ms=",
          inspect(div(arinc_time, 1000)),
          " signs_ui_ms=",
          inspect(div(ui_time, 1000))
        ])

      {:error, _} ->
        Logger.info([
          "update_single_line: ",
          encoded,
          " pid=",
          inspect(self()),
          " arinc_ms=",
          inspect(div(arinc_time, 1000))
        ])
    end

    result
  end

  def process(
        {:update_sign, [{station, zone}, top_line, bottom_line, duration, start_secs]},
        state
      ) do
    top_cmd = to_command(top_line, duration, start_secs, zone, 1)
    bottom_cmd = to_command(bottom_line, duration, start_secs, zone, 2)

    encoded =
      URI.encode_query(
        MsgType: "SignContent",
        uid: state.uid,
        sta: station,
        c: top_cmd,
        c: bottom_cmd
      )

    {arinc_time, result} = :timer.tc(fn -> send_post(state.http_poster, encoded) end)

    case result do
      {:ok, _} ->
        {ui_time, _} = :timer.tc(fn -> update_ui(state.http_poster, encoded) end)

        Logger.info([
          "update_sign: ",
          encoded,
          " pid=",
          inspect(self()),
          " arinc_ms=",
          inspect(div(arinc_time, 1000)),
          " signs_ui_ms=",
          inspect(div(ui_time, 1000))
        ])

      {:error, _} ->
        Logger.info([
          "update_sign: ",
          encoded,
          " pid=",
          inspect(self()),
          " arinc_ms=",
          inspect(div(arinc_time, 1000))
        ])
    end

    result
  end

  def process({:send_audio, [{station, zones}, audios, priority, timeout]}, state) do
    case audios do
      {a1, a2} ->
        process_send_audio(station, zones, a1, priority, timeout, state)
        process_send_audio(station, zones, a2, priority, timeout, state)

      a ->
        process_send_audio(station, zones, a, priority, timeout, state)
    end
  end

  @spec process_send_audio(String.t(), [String.t()], Content.Audio.t(), integer(), integer(), t()) ::
          post_result()
  defp process_send_audio(station, zones, audio, priority, timeout, state) do
    case Content.Audio.to_params(audio) do
      {:canned, {message_id, vars, type}} ->
        encoded =
          [
            MsgType: "Canned",
            uid: state.uid,
            mid: message_id,
            var: Enum.join(vars, ","),
            typ: audio_type(type),
            sta: "#{station}#{zone_bitmap(zones)}",
            pri: priority,
            tim: timeout
          ]
          |> URI.encode_query()

        {time, result} = :timer.tc(fn -> send_post(state.http_poster, encoded) end)

        Logger.info([
          "send_audio: ",
          encoded,
          " pid=",
          inspect(self()),
          " arinc_ms=",
          inspect(div(time, 1000))
        ])

        result

      {:ad_hoc, {text, type}} ->
        encoded =
          [
            MsgType: "AdHoc",
            uid: state.uid,
            msg: PaEss.Utilities.replace_abbreviations(text),
            typ: audio_type(type),
            sta: "#{station}#{zone_bitmap(zones)}",
            pri: priority,
            tim: timeout
          ]
          |> URI.encode_query()

        {time, result} = :timer.tc(fn -> send_post(state.http_poster, encoded) end)

        Logger.info([
          "send_custom_audio: ",
          encoded,
          " pid=",
          inspect(self()),
          " arinc_ms=",
          inspect(div(time, 1000))
        ])

        result

      nil ->
        {:ok, :no_audio}
    end
  end

  @spec to_command(
          Content.Message.t(),
          non_neg_integer(),
          non_neg_integer() | :now,
          String.t(),
          1 | 2
        ) :: String.t()
  def to_command(msg, duration, start_secs, zone, line_no) do
    "#{start_display(start_secs)}e#{duration}~#{zone}#{line_no}#{message_display(msg)}"
  end

  defp sign_host, do: Application.get_env(:realtime_signs, :sign_head_end_host)
  defp sign_url, do: "http://#{sign_host()}/mbta/cgi-bin/RemoteMsgsCgi.exe"
  defp sign_ui_host, do: Application.get_env(:realtime_signs, :sign_ui_url)
  defp sign_ui_url, do: "http://#{sign_ui_host()}/messages"

  defp start_display(:now), do: ""
  defp start_display(seconds_from_midnight), do: "t#{seconds_from_midnight}"

  @spec message_display(Content.Message.t()) :: String.t()
  defp message_display(msg) when is_map(msg) do
    case Content.Message.to_string(msg) do
      str when is_binary(str) ->
        ~s(-"#{str}")

      pages ->
        pages
        |> rotate()
        |> Enum.map(fn {str, duration} -> ~s(-"#{str}".#{duration - 1}) end)
        |> Enum.join()
    end
  end

  # When sending a list of pages [a, b, c] to ARINC, the display starts with b, so move
  # the last item in the list to the front, go get proper pagination.
  defp rotate(pages) do
    {last, rest} = List.pop_at(pages, -1)
    [last | rest]
  end

  @spec zone_bitmap([String.t()]) :: String.t()
  defp zone_bitmap(zones) do
    zones
    |> Enum.map(&zone_to_bit/1)
    |> Enum.reduce(0, fn bit, acc -> bit ||| acc end)
    |> Integer.to_string(2)
    |> String.pad_leading(6, "0")
  end

  # bitmap representing zone: m c n s e w
  @spec zone_to_bit(String.t()) :: non_neg_integer
  defp zone_to_bit("m"), do: 1 <<< 5
  defp zone_to_bit("c"), do: 1 <<< 4
  defp zone_to_bit("n"), do: 1 <<< 3
  defp zone_to_bit("s"), do: 1 <<< 2
  defp zone_to_bit("e"), do: 1 <<< 1
  defp zone_to_bit("w"), do: 1 <<< 0

  defp audio_type(:audio_visual), do: "0"
  defp audio_type(:audio), do: "1"
  defp audio_type(:visual), do: "2"

  @spec send_post(module(), binary()) :: post_result()
  defp send_post(http_poster, query) do
    case http_poster.post(
           sign_url(),
           query,
           [
             {"Content-type", "application/x-www-form-urlencoded"}
           ],
           hackney: [pool: :arinc_pool]
         ) do
      {:ok, %HTTPoison.Response{status_code: status}} when status >= 200 and status < 300 ->
        {:ok, :sent}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.warn("head_end_post_error: response had status code: #{inspect(status)}")
        {:error, :bad_status}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("head_end_post_error: #{inspect(reason)}")
        {:error, :post_error}
    end
  end

  @spec update_ui(module(), String.t()) ::
          {:ok, :sent} | {:error, :bad_status} | {:error, :post_error}
  def update_ui(http_poster, query) do
    key = Application.get_env(:realtime_signs, :sign_ui_api_key)

    case http_poster.post(
           sign_ui_url(),
           query,
           [
             {"Content-type", "application/x-www-form-urlencoded"},
             {"x-api-key", key}
           ],
           hackney: [pool: :arinc_pool]
         ) do
      {:ok, %HTTPoison.Response{status_code: status}} when status == 201 ->
        {:ok, :sent}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.warn("sign_ui_post_error: response had status code: #{inspect(status)}")
        {:error, :bad_status}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.info("sign_ui_post_error: #{inspect(reason)}")
        {:error, :post_error}
    end
  end

  defp schedule_check_queue(pid, ms) do
    Process.send_after(pid, :check_queue, ms)
  end
end
