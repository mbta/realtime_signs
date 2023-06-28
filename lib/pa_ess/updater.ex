defmodule PaEss.Updater do
  @callback update_sign(PaEss.text_id(), top_line, bottom_line, duration, start, sign_id) ::
              {:ok, :sent} | {:error, :bad_status} | {:error, :post_error}
            when top_line: Content.Message.t(),
                 bottom_line: Content.Message.t(),
                 duration: integer(),
                 start: integer() | :now,
                 sign_id: String.t()

  @callback send_audio(PaEss.audio_id(), audios, priority, timeout, sign_id) ::
              {:ok, :sent} | {:error, any()}
            when priority: integer(),
                 timeout: integer(),
                 audios: [Content.Audio.t()],
                 sign_id: String.t()
end
