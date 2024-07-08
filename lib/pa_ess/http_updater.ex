defmodule PaEss.HttpUpdater do
  import Bitwise

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

  use GenServer
  require Logger

  def start_link(index) do
    GenServer.start_link(__MODULE__, index, name: :"HttpUpdater/#{index}")
  end

  def init(index) do
    schedule_check_queue(self(), 30)

    max_send_rate_per_sec =
      (32 / Application.get_env(:realtime_signs, :number_of_http_updaters))
      |> Float.ceil()
      |> Kernel.trunc()

    {:ok,
     %{
       http_poster: Application.get_env(:realtime_signs, :http_poster_mod),
       queue_mod: MessageQueue,
       updater_index: index,
       internal_counter: 0,
       timestamp: div(System.system_time(:millisecond), 500),
       avg_ms_between_sends: round(1000 / max_send_rate_per_sec)
     }}
  end

  def handle_info(:check_queue, state) do
    before_time = System.monotonic_time(:millisecond)

    if item = state.queue_mod.get_message() do
      process(item, state)
    end

    send_time = System.monotonic_time(:millisecond) - before_time
    wait_time = max(0, state.avg_ms_between_sends - send_time)
    schedule_check_queue(self(), wait_time)

    if state.internal_counter >= 15 do
      {:noreply,
       %{state | timestamp: div(System.system_time(:millisecond), 500), internal_counter: 0}}
    else
      {:noreply, %{state | internal_counter: state.internal_counter + 1}}
    end
  end

  def process(
        {:update_sign, [{station, zone}, top_line, bottom_line, duration, start_secs, sign_id]},
        state
      ) do
    top_cmd = to_command(top_line, duration, start_secs, zone, 1)
    bottom_cmd = to_command(bottom_line, duration, start_secs, zone, 2)
    uid = get_uid(state)

    encoded =
      URI.encode_query(
        MsgType: "SignContent",
        uid: uid,
        sta: station,
        c: top_cmd,
        c: bottom_cmd
      )

    {arinc_ms, signs_ui_ms, result} = send_payload(encoded, state)

    log("update_sign", encoded,
      arinc_ms: arinc_ms,
      signs_ui_ms: signs_ui_ms,
      top_line: inspect(top_line),
      bottom_line: inspect(bottom_line),
      sign_id: sign_id,
      message_type:
        case Engine.Config.sign_config(sign_id) do
          type when is_atom(type) -> type
          tuple when is_tuple(tuple) -> elem(tuple, 0)
          _ -> nil
        end
    )

    result
  end

  def process(
        {:send_audio, [{station, zones}, audios, priority, timeout, sign_id, extra_logs]},
        state
      ) do
    for {audio, extra_logs} <- Enum.zip(audios, extra_logs) do
      process_send_audio(station, zones, audio, priority, timeout, sign_id, extra_logs, state)
    end
    |> List.last()
  end

  @spec process_send_audio(
          String.t(),
          [String.t()],
          Content.Audio.value(),
          integer(),
          integer(),
          String.t(),
          list,
          t()
        ) ::
          post_result()
  defp process_send_audio(station, zones, audio, priority, timeout, sign_id, extra_logs, state) do
    case audio do
      {:canned, {message_id, vars, type}} ->
        encoded =
          [
            MsgType: "Canned",
            uid: get_uid(state),
            mid: message_id,
            var: Enum.join(vars, ","),
            typ: audio_type(type),
            sta: "#{station}#{zone_bitmap(zones)}",
            pri: priority,
            tim: timeout
          ]
          |> URI.encode_query()

        {arinc_ms, signs_ui_ms, result} = send_payload(encoded, state)

        log(
          "send_audio",
          encoded,
          [arinc_ms: arinc_ms, signs_ui_ms: signs_ui_ms, sign_id: sign_id] ++ extra_logs
        )

        result

      {:ad_hoc, {text, type}} ->
        encoded =
          [
            MsgType: "AdHoc",
            uid: get_uid(state),
            msg: PaEss.Utilities.replace_abbreviations(text),
            typ: audio_type(type),
            sta: "#{station}#{zone_bitmap(zones)}",
            pri: priority,
            tim: timeout
          ]
          |> URI.encode_query()

        {arinc_ms, signs_ui_ms, result} = send_payload(encoded, state)

        log(
          "send_custom_audio",
          encoded,
          [arinc_ms: arinc_ms, signs_ui_ms: signs_ui_ms, sign_id: sign_id] ++ extra_logs
        )

        result

      nil ->
        {:ok, :no_audio}
    end
  end

  defp send_payload(body, %{http_poster: http_poster}) do
    {arinc_time, result} = :timer.tc(fn -> send_post(http_poster, body) end)

    {ui_time, _} =
      case result do
        {:ok, _} -> :timer.tc(fn -> update_ui(http_poster, body) end)
        {:error, _} -> {0, nil}
      end

    {div(arinc_time, 1000), div(ui_time, 1000), result}
  end

  defp log(log_token, body, extras) do
    fields = Enum.map(extras, fn {k, v} -> "#{k}=#{v}" end) |> Enum.join(" ")
    Logger.info("#{log_token}: #{body} pid=#{inspect(self())} #{fields}")
  end

  @spec to_command(
          Content.Message.value(),
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

  @spec message_display(Content.Message.value()) :: String.t()
  defp message_display(msg) do
    case msg do
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
    if sign_host() do
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
    else
      {:ok, :sent}
    end
  end

  @spec update_ui(module(), String.t()) ::
          {:ok, :sent} | {:error, :bad_status} | {:error, :post_error}
  def update_ui(http_poster, query) do
    if sign_ui_host() do
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
    else
      {:ok, :sent}
    end
  end

  defp get_uid(state) do
    <<uid::unsigned-integer-31>> =
      <<state.timestamp::unsigned-integer-22, state.updater_index::unsigned-integer-5,
        state.internal_counter::unsigned-integer-4>>

    uid
  end

  defp schedule_check_queue(pid, ms) do
    Process.send_after(pid, :check_queue, ms)
  end
end
