defmodule Engine.PaMessages do
  use GenServer
  require Logger

  alias PaMessages.PaMessage

  @minute_in_ms 1000 * 60

  @callback for_sign(String.t()) :: [PaMessage.t()]
  def for_sign(sign_id, table \\ :pa_messages) do
    case :ets.lookup(table, sign_id) do
      [{^sign_id, pa_messages}] -> pa_messages
      _ -> []
    end
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(:pa_messages, [:named_table, read_concurrency: true])
    schedule_update(self())
    {:ok, %{table: :pa_messages}}
  end

  @impl true
  def handle_info(:update, state) do
    schedule_update(self())

    case get_active_pa_messages() do
      {:ok, pa_messages} ->
        for pa_message <- pa_messages, sign_id <- pa_message.sign_ids do
          {sign_id, pa_message}
        end
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> then(&Signs.Utilities.EtsUtils.write_ets(state.table, &1, []))

      {:error, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("pa_messages_response_error: status_code=#{status_code} body=#{body}")

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("pa_messages_response_error: reason=#{reason}")

      {:error, error} ->
        Logger.error("pa_messages_response_error: error=#{inspect(error)}")
    end

    {:noreply, state}
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
