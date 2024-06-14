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
          recent_sends = send_pa_messages(pa_messages, state.pa_messages_last_sent)
          handle_inactive_pa_messages(recent_sends, state.pa_messages_last_sent)

          %{state | pa_messages_last_sent: recent_sends}

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

  defp send_pa_messages(pa_messages, pa_messages_last_sent) do
    for %{
          "id" => pa_id,
          "visual_text" => visual_text,
          "audio_text" => audio_text,
          "interval_in_minutes" => interval_in_minutes,
          "priority" => priority,
          "sign_ids" => sign_ids
        } <- pa_messages,
        into: %{} do
      active_pa_message = %PaMessage{
        id: pa_id,
        visual_text: visual_text,
        audio_text: audio_text,
        priority: priority,
        sign_ids: sign_ids,
        interval_in_ms: interval_in_minutes * @minute_in_ms
      }

      {_, last_sent_time} = Map.get(pa_messages_last_sent, pa_id, {nil, nil})

      time_since_last_send =
        if last_sent_time,
          do: DateTime.diff(DateTime.utc_now(), last_sent_time, :millisecond),
          else: active_pa_message.interval_in_ms

      if time_since_last_send >= active_pa_message.interval_in_ms do
        send_pa_message(active_pa_message)
        {pa_id, {active_pa_message, DateTime.utc_now()}}
      else
        {pa_id, {active_pa_message, last_sent_time}}
      end
    end
  end

  defp send_pa_message(pa_message) do
    Enum.each(pa_message.sign_ids, fn sign_id ->
      Logger.info("pa_message: action=send id=#{pa_message.id} destination=#{sign_id}")

      send(
        String.to_existing_atom("Signs/#{sign_id}"),
        {:play_pa_message, pa_message}
      )
    end)
  end

  defp handle_inactive_pa_messages(active_pa_messages, pa_messages_last_sent) do
    Enum.each(pa_messages_last_sent, fn {pa_id, {pa_message, _}} ->
      if pa_id not in Map.keys(active_pa_messages) do
        Logger.info("pa_message: action=message_deactivated id=#{pa_id}")

        Enum.each(pa_message.sign_ids, fn sign_id ->
          send(
            String.to_existing_atom("Signs/#{sign_id}"),
            {:deactivate_pa_message, pa_message.id}
          )
        end)
      end
    end)
  end

  defp get_active_pa_messages() do
    active_pa_messages_url = Application.get_env(:realtime_signs, :active_pa_messages_url)
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
         {:ok, pa_messages} <- Jason.decode(body) do
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
