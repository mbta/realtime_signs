defmodule PaEss.ScuUpdater do
  use GenStage
  require Logger

  def start_link(id) do
    GenStage.start_link(__MODULE__, id, name: :"ScuUpdater/#{id}")
  end

  @impl true
  def init(id) do
    {:consumer, %{}, subscribe_to: [{PaEss.ScuQueue.stage_name(id), []}]}
  end

  @impl true
  def handle_events([{:message, scu_id, payload, logs}], _from, state) do
    body = Jason.encode!(payload)
    log("play_message", logs)

    if send_to_scu(scu_id, "/message", body) == :ok do
      send_to_signs_ui(scu_id, "/message", body)
    end

    {:noreply, [], state}
  end

  def handle_events([{:background, scu_id, payload, logs}], _from, state) do
    body = Jason.encode!(payload)
    log("set_background_message", logs)

    if send_to_scu(scu_id, "/background", body) == :ok do
      send_to_signs_ui(scu_id, "/background", body)
    end

    {:noreply, [], state}
  end

  defp send_to_scu(scu_id, path, body) do
    http_poster = Application.get_env(:realtime_signs, :http_poster_mod)
    scu_ip_map = Application.get_env(:realtime_signs, :scu_ip_map)
    scully_api_key = Application.get_env(:realtime_signs, :scully_api_key)

    if scu_ip_map do
      http_poster.post(
        "http://#{Map.fetch!(scu_ip_map, scu_id)}#{path}",
        body,
        [{"Content-type", "application/json"}, {"x-api-key", scully_api_key}],
        hackney: [pool: :arinc_pool]
      )
      |> case do
        {:ok, %HTTPoison.Response{status_code: status}} when status in 200..299 ->
          :ok

        {:ok, %HTTPoison.Response{status_code: status}} ->
          Logger.warn("scu_error: status=#{inspect(status)}")
          :error

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.warn("scu_error: #{inspect(reason)}")
          :error
      end
    else
      :ok
    end
  end

  defp send_to_signs_ui(scu_id, path, body) do
    http_poster = Application.get_env(:realtime_signs, :http_poster_mod)
    sign_ui_url = Application.get_env(:realtime_signs, :sign_ui_url)
    sign_ui_api_key = Application.get_env(:realtime_signs, :sign_ui_api_key)

    if sign_ui_url do
      http_poster.post(
        "http://#{sign_ui_url}#{path}",
        body,
        [
          {"Content-type", "application/json"},
          {"x-api-key", sign_ui_api_key},
          {"x-scu-id", scu_id}
        ],
        hackney: [pool: :arinc_pool]
      )
      |> case do
        {:ok, %HTTPoison.Response{status_code: status}} when status in 200..299 ->
          nil

        {:ok, %HTTPoison.Response{status_code: status}} ->
          Logger.warn("signs_ui_error: status=#{inspect(status)}")

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.warn("signs_ui_error: #{inspect(reason)}")
      end
    end
  end

  defp log(token, items) do
    fields =
      Enum.map([pid: inspect(self())] ++ items, fn {k, v} -> "#{k}=#{v}" end) |> Enum.join(" ")

    Logger.info("#{token}: #{fields}")
  end
end
