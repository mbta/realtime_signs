defmodule Engine.PaMessages do
  use GenServer
  require Logger

  alias PaMessages.PaMessage

  @type state :: %{
          pa_message_timers_table: :ets.tab()
        }

  @pa_message_timers_table :pa_message_timers
  @minute_in_ms 1000 * 60

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Add some delay to wait for sign processes to come up before sending PA messages
    Process.send_after(self(), :update, 10000)
    state = %{pa_message_timers_table: @pa_message_timers_table}
    create_table(state)
    {:ok, state}
  end

  def create_table(state) do
    :ets.new(state.pa_message_timers_table, [:named_table, read_concurrency: true])
  end

  @impl true
  def handle_info(:update, state) do
    schedule_update(self())

    case get_active_pa_messages() do
      {:ok, pa_messages} ->
        schedule_pa_messages(pa_messages, state.pa_message_timers_table)
        |> handle_inactive_pa_messages(state.pa_message_timers_table)

      {:error, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.warn("pa_messages_response_error: status_code=#{status_code} body=#{body}")

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("pa_messages_response_error: reason=#{reason}")

      {:error, error} ->
        Logger.warn("pa_messages_response_error: error=#{inspect(error)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:send_pa_message, pa_message}, state) do
    Enum.each(pa_message.sign_ids, fn sign_id ->
      send(
        String.to_existing_atom("Signs/#{sign_id}"),
        {:play_pa_message, pa_message}
      )
    end)

    {:noreply, state}
  end

  defp schedule_pa_messages(pa_messages, table) do
    for %{
          "id" => pa_id,
          "visual_text" => visual_text,
          "audio_text" => audio_text,
          "interval_in_minutes" => interval_in_minutes,
          "priority" => priority,
          "sign_ids" => sign_ids
        } <- pa_messages do
      active_pa_message = %PaMessage{
        id: pa_id,
        visual_text: visual_text,
        audio_text: audio_text,
        priority: priority,
        sign_ids: ["Silver_Line.South_Station_EB" | sign_ids],
        interval_in_ms: interval_in_minutes * @minute_in_ms
      }

      case get_pa_message_timer(pa_id, table) do
        {timer_ref, existing_pa_message}
        when existing_pa_message.interval_in_ms != active_pa_message.interval_in_ms ->
          case Process.read_timer(timer_ref) do
            false ->
              schedule_pa_message(active_pa_message, active_pa_message.interval_in_ms, table)

            remaining_ms ->
              ms_elapsed = existing_pa_message.interval_in_ms - remaining_ms
              temp_interval = (active_pa_message.interval_in_ms - ms_elapsed) |> max(0)
              cancel_pa_timer(timer_ref, pa_id)
              schedule_pa_message(active_pa_message, temp_interval, table)
          end

        {timer, _} ->
          if Process.read_timer(timer) == false do
            schedule_pa_message(active_pa_message, active_pa_message.interval_in_ms, table)
          end

        nil ->
          schedule_pa_message(active_pa_message, 0, table)
      end

      pa_id
    end
  end

  defp schedule_pa_message(pa_message, interval_in_ms, table) do
    Logger.info(
      "pa_message: action=scheduled id=#{pa_message.id} interval_ms=#{interval_in_ms} sign_ids=#{inspect(pa_message.sign_ids)}"
    )

    timer_ref =
      Process.send_after(
        self(),
        {:send_pa_message, pa_message},
        interval_in_ms
      )

    :ets.insert(
      table,
      {pa_message.id, {timer_ref, pa_message}}
    )
  end

  defp handle_inactive_pa_messages(active_pa_ids, table) do
    :ets.tab2list(table)
    |> Enum.each(fn {pa_id, {timer_ref, pa_message}} ->
      if pa_id not in active_pa_ids do
        cancel_pa_timer(timer_ref, pa_id)
        delete_pa_message(pa_message, table)
      end
    end)
  end

  defp cancel_pa_timer(timer_ref, pa_id) do
    Logger.info("pa_message: action=timer_canceled id=#{pa_id}")
    Process.cancel_timer(timer_ref)
  end

  defp delete_pa_message(pa_message, table) do
    Logger.info("pa_message: action=message_deleted id=#{pa_message.id}")

    Enum.each(pa_message.sign_ids, fn sign_id ->
      send(
        String.to_existing_atom("Signs/#{sign_id}"),
        {:delete_pa_message, pa_message.id}
      )
    end)

    :ets.delete(table, pa_message.id)
  end

  defp get_pa_message_timer(pa_id, table) do
    case :ets.lookup(table, pa_id) do
      [{^pa_id, timer}] -> timer
      _ -> nil
    end
  end

  defp get_active_pa_messages() do
    active_pa_messages_url =
      Application.get_env(:realtime_signs, :screenplay_url) <>
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
