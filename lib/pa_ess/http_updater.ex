defmodule PaEss.HttpUpdater do
  @moduledoc """
  Behaviour that HTTP POSTs sign updates to the PA/ESS server.
  """

  @behaviour PaEss.Updater

  @type t :: %{
    http_poster: module(),
    uid: integer()
  }

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    http_poster = opts[:http_poster] || Application.get_env(:realtime_signs, :http_poster_mod)
    GenServer.start_link(__MODULE__, [http_poster: http_poster], name: __MODULE__)
  end

  @impl PaEss.Updater
  def update_sign(pa_ess_id, line_no, msg, duration, start_secs) do
    update_sign(__MODULE__, pa_ess_id, line_no, msg, duration, start_secs)
  end

  def update_sign(pid, pa_ess_id, line_no, msg, duration, start_secs) do
    GenServer.call(pid, {:update_sign, pa_ess_id, line_no, msg, duration, start_secs})
  end

  @impl GenServer
  def init(opts) do
    {:ok, %{http_poster: opts[:http_poster], uid: 0}}
  end

  @impl GenServer
  def handle_call({:update_sign, {station, zone}, line_no, msg, duration, start_secs}, _from, state) do
    cmd = "#{start_display(start_secs)}e#{duration}~#{zone}#{line_no}-#{message_display(msg)}"
    encoded = URI.encode_query([MsgType: "SignContent", uid: state.uid, sta: station, c: cmd])
    Logger.info(["update_sign: ", encoded])

    result = case state.http_poster.post(url(), encoded, [{"Content-type", "application/x-www-form-urlencoded"}]) do
      {:ok, %HTTPoison.Response{status_code: status}} when status >= 200 and status < 300 ->
        {:ok, :sent}
      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.warn("head_end_post_error: response had status code: #{inspect status}")
        {:error, :bad_status}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("head_end_post_error: #{inspect reason}")
        {:error, :post_error}
    end

    {:reply, result, %{state | uid: state.uid + 1}}
  end

  defp host, do: Application.get_env(:realtime_signs, :sign_head_end_host)
  defp url, do: "http://#{host()}/mbta/cgi-bin/RemoteMsgsCgi.exe"

  defp start_display(:now), do: ""
  defp start_display(seconds_from_midnight), do: "t#{seconds_from_midnight}"

  defp message_display(msg) when is_atom(msg), do: "#{msg}"
  defp message_display(msg) when is_map(msg), do: ~s("#{Content.Message.to_string(msg)}")
end
