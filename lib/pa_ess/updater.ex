defmodule PaEss.Updater do
  @callback update_single_line(PaEss.id, line_no, Content.Message.t(), duration, start, integer) ::
    {:ok, :sent} | {:error, :bad_status} | {:error, :post_error}
    when line_no: String.t(), duration: integer(), start: integer() | :now

  @callback update_sign(PaEss.id, top_line, bottom_line, duration, start, integer) ::
    {:ok, :sent} | {:error, :bad_status} | {:error, :post_error}
    when top_line: Content.Message.t(), bottom_line: Content.Message.t(), duration: integer(), start: integer() | :now

  @callback send_audio(PaEss.id, Content.Audio.t(), priority, timeout, integer) ::
    {:ok, :sent} | {:error, any()}
    when priority: integer(), timeout: integer()
end
