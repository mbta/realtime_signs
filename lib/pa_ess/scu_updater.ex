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
    log("play_message", logs)

    if send_to_scu(scu_id, "/message", payload) == :ok do
      send_to_signs_ui(scu_id, "/message", payload)
    end

    {:noreply, [], state}
  end

  def handle_events([{:background, scu_id, payload, logs}], _from, state) do
    log("set_background_message", logs)

    if send_to_scu(scu_id, "/background", payload) == :ok do
      send_to_signs_ui(scu_id, "/background", payload)
    end

    {:noreply, [], state}
  end

  defp send_to_scu(scu_id, path, body) do
    http_poster = Application.get_env(:realtime_signs, :http_poster_mod)
    scu_ip_map = Application.get_env(:realtime_signs, :scu_ip_map)
    scully_api_key = Application.get_env(:realtime_signs, :scully_api_key)

    address = scu_ip_map[scu_id] || scu_ip_map["*"]

    if address do
      http_poster.post("http://#{address}#{path}",
        headers: [x_api_key: scully_api_key],
        json: body
      )
      |> case do
        {:ok, %Req.Response{status: status}} when status in 200..299 ->
          :ok

        {:ok, %Req.Response{status: status}} ->
          Logger.warning("scu_error: status=#{inspect(status)} scu_id=#{inspect(scu_id)}")
          :error

        {:error, error} ->
          Logger.warning("scu_error: scu_id=#{inspect(scu_id)} #{inspect(error)}")
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
      http_poster.post("http://#{sign_ui_url}#{path}",
        headers: [x_api_key: sign_ui_api_key, x_scu_id: scu_id],
        json: body
      )
      |> case do
        {:ok, %Req.Response{status: status}} when status in 200..299 ->
          nil

        {:ok, %Req.Response{status: status}} ->
          Logger.warning("signs_ui_error: status=#{inspect(status)}")

        {:error, error} ->
          Logger.warning("signs_ui_error: #{inspect(error)}")
      end
    end
  end

  defp log(token, items) do
    fields =
      Enum.map([pid: inspect(self())] ++ items, fn {k, v} -> "#{k}=#{v}" end) |> Enum.join(" ")

    Logger.info("#{token}: #{fields}")
  end
end
