defmodule PaEss.Updater do
  @callback update_sign(PaEss.id, line_no, Content.Message.t(), duration, start) ::
    {:ok, :sent} | {:error, :bad_status} | {:error, :post_error}
    when line_no: String.t(), duration: integer(), start: integer() | :now

  @callback send_audio(PaEss.id, Content.Audio.t(), priority, type) ::
    {:ok, :sent} | {:error, any()}
    when priority: integer(), type: :audio | :visual | :audio_visual
end
