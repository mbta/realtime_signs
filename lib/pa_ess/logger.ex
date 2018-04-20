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
      DateTime.to_iso8601(DateTime.utc_now()),
      ",",
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
end
