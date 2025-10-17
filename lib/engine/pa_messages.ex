defmodule Engine.PaMessages do
  use GenServer
  require Logger

  alias PaMessages.PaMessage

  @type state :: %{
          pa_messages_last_sent: %{non_neg_integer() => DateTime.t()}
        }

  @minute_in_ms 1000 * 60

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Add some delay to wait for sign processes to come up before sending PA messages
    Process.send_after(self(), :update, 10000)
    {:ok, %{pa_messages_last_sent: %{}}}
  end

  @impl true
  def handle_info(:update, state) do
    schedule_update(self())

    state =
      case get_active_pa_messages() do
        {:ok, pa_messages} ->
          {selected_pa_messages, state} = select_pa_messages(pa_messages, state)
          play_pa_messages(selected_pa_messages)
          state

        {:error, %HTTPoison.Response{status_code: status_code, body: body}} ->
          Logger.error("pa_messages_response_error: status_code=#{status_code} body=#{body}")
          state

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("pa_messages_response_error: reason=#{reason}")
          state

        {:error, error} ->
          Logger.error("pa_messages_response_error: error=#{inspect(error)}")
          state
      end

    {:noreply, state}
  end

  defp select_pa_messages(pa_messages, state) do
    now = DateTime.utc_now()

    Enum.flat_map_reduce(pa_messages, state, fn message, state ->
      last_sent = Map.get(state.pa_messages_last_sent, message.id, DateTime.from_unix!(0))

      if DateTime.diff(DateTime.utc_now(), last_sent, :millisecond) >= message.interval_in_ms do
        {[message], put_in(state, [:pa_messages_last_sent, message.id], now)}
      else
        {[], state}
      end
    end)
  end

  defp play_pa_messages(pa_messages) do
    Enum.flat_map(pa_messages, fn message ->
      for sign_id <- message.sign_ids,
          {sign, should_play?} = GenServer.call(:"Signs/#{sign_id}", {:play_pa_message, message}),
          should_play? do
        sign
      end
      |> Enum.group_by(& &1.pa_ess_loc)
      |> Enum.map(fn {_, [first | _] = signs} ->
        {message,
         %{
           first
           | audio_zones: Enum.flat_map(signs, & &1.audio_zones) |> Enum.uniq(),
             id: Enum.map_join(signs, ",", & &1.id)
         }}
      end)
    end)
    |> Enum.each(fn {message, sign} ->
      Signs.Utilities.Audio.send_audio(sign, [message])
    end)
  end

  defp get_active_pa_messages() do
    active_pa_messages_url =
      Application.get_env(:realtime_signs, :screenplay_base_url) <>
        Application.get_env(:realtime_signs, :active_pa_messages_path)

    http_client = Application.get_env(:realtime_signs, :http_client)

    with {:ok, response} <-
           http_client.get(
             active_pa_messages_url,
             [
               {"x-api-key", Application.get_env(:realtime_signs, :screenplay_api_key)}
             ],
             timeout: 2000,
             recv_timeout: 2000
           ),
         %{status_code: 200, body: body} <- response,
         {:ok, data} <- Jason.decode(body) do
      pa_messages =
        for %{
              "id" => pa_id,
              "visual_text" => visual_text,
              "audio_text" => audio_text,
              "audio_url" => audio_url,
              "interval_in_minutes" => interval_in_minutes,
              "priority" => priority,
              "sign_ids" => sign_ids
            } <- data do
          %PaMessage{
            id: pa_id,
            visual_text: visual_text,
            audio_text: audio_text,
            audio_url: audio_url,
            priority: priority,
            sign_ids: sign_ids,
            interval_in_ms: interval_in_minutes * @minute_in_ms
          }
        end

      {:ok, pa_messages}
    else
      error ->
        {:error, error}
    end
  end

  defp schedule_update(pid) do
    Process.send_after(pid, :update, 1_000)
  end
end
