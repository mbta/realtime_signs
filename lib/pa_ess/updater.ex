defmodule PaEss.Updater do
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
                 audios: [Content.Audio.t()]
end
