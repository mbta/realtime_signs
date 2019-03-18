defmodule PaEss.Updater do
  @callback update_single_line(PaEss.text_id(), line_no, Content.Message.t(), duration, start) ::
              {:ok, :sent} | {:error, :bad_status} | {:error, :post_error}
            when line_no: String.t(), duration: integer(), start: integer() | :now

  @callback update_sign(PaEss.text_id(), top_line, bottom_line, duration, start) ::
              {:ok, :sent} | {:error, :bad_status} | {:error, :post_error}
            when top_line: Content.Message.t(),
                 bottom_line: Content.Message.t(),
                 duration: integer(),
                 start: integer() | :now

  @callback send_audio(PaEss.audio_id(), audios, priority, timeout) ::
              {:ok, :sent} | {:error, any()}
            when priority: integer(),
                 timeout: integer(),
                 audios: Content.Audio.t() | {Content.Audio.t(), Content.Audio.t()}

  @callback send_custom_audio(PaEss.audio_id(), Content.Audio.Custom.t(), priority, timeout) ::
              {:ok, :sent} | {:error, any()}
            when priority: integer(), timeout: integer()
end
