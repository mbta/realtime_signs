defmodule PaEss.Logger do
  @moduledoc """
  A behaviour that signs can use to log their updates
  rather than sending it to the Pa/Ess HTTP server.
  """

  @behaviour PaEss.Updater

  require Logger

  @impl true
  def update_single_line(text_id, line_no, msg, duration, start_secs) do
    line = [
      now(),
      "update_single_line,",
      inspect(text_id),
      ",",
      "#{line_no}",
      ",",
      inspect(Content.Message.to_string(msg)),
      ",",
      "#{duration}",
      ",",
      "#{start_secs}"
    ]

    Logger.info(line)
    {:ok, :sent}
  end

  @impl true
  def update_sign(text_id, top_line, bottom_line, duration, start_secs) do
    line = [
      now(),
      "update_sign,",
      inspect(text_id),
      ",",
      inspect(Content.Message.to_string(top_line)),
      ",",
      inspect(Content.Message.to_string(bottom_line)),
      ",",
      "#{duration}",
      ",",
      "#{start_secs}"
    ]

    Logger.info(line)
    {:ok, :sent}
  end

  @impl true
  def send_audio(audio_id, audios, priority, timeout) do
    audio_text =
      case audios do
        {a1, a2} -> inspect([Content.Audio.to_params(a1), Content.Audio.to_params(a2)])
        a -> inspect(Content.Audio.to_params(a))
      end

    line = [
      now(),
      "send_audio,",
      inspect(audio_id),
      ",",
      audio_text,
      ",",
      priority,
      ",",
      timeout
    ]

    Logger.info(line)
    {:ok, :sent}
  end

  defp now do
    DateTime.to_iso8601(DateTime.utc_now())
  end
end
