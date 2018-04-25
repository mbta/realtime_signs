defmodule PaEss.Logger do
  @moduledoc """
  A behaviour that signs can use to append their updates to a file,
  rather than sending it to the Pa/Ess HTTP server.
  """

  @behaviour PaEss.Updater

  require Logger

  @impl true
  def update_sign(pa_ess_id, line_no, msg, duration, start_secs) do
    line = [
      now(),
      "update_sign,",
      inspect(pa_ess_id),
      ",",
      "#{line_no}",
      ",",
      Content.Message.to_string(msg),
      ",",
      "#{duration}",
      ",",
      "#{start_secs}"
    ]

    File.mkdir("log")
    File.write!("log/pa_ess_updates.log", line ++ ["\n"], [:append])
    Logger.info(line)
    {:ok, :sent}
  end

  @impl true
  def send_audio(pa_ess_id, msg, priority, type, timeout) do
    line = [
      now(),
      "send_audio,",
      inspect(pa_ess_id),
      ",",
      inspect(Content.Audio.to_params(msg)),
      ",",
      priority,
      ",",
      inspect(type),
      ",",
      timeout
    ]

    Logger.info(line)
    File.mkdir("log")
    File.write!("log/pa_ess_updates.log", line ++ ["\n"], [:append])
    {:ok, :sent}
  end

  defp now do
    DateTime.to_iso8601(DateTime.utc_now())
  end
end
