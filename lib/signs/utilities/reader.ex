defmodule Signs.Utilities.Reader do
  @spec read_sign(Signs.Realtime.t(), Content.Message.t(), Content.Message.t()) ::
          Signs.Realtime.t()
  def read_sign(%{tick_read: 0} = sign, top_content, bottom_content) do
    {audios, sign} = Signs.Utilities.Audio.from_sign(sign, top_content, bottom_content)

    if audios != [] do
      send_audio(sign, audios)
    end

    %{sign | tick_read: sign.read_period_seconds}
  end

  def read_sign(sign, _, _) do
    sign
  end

  @spec do_announcements(Signs.Realtime.t(), Content.Message.t(), Content.Message.t()) ::
          Signs.Realtime.t()
  def do_announcements(sign, top_content, bottom_content) do
    {audios, sign} = Signs.Utilities.Audio.get_announcements(sign, top_content, bottom_content)

    if audios != [] do
      send_audio(sign, audios)
      update_in(sign.tick_read, &if(&1 < 120, do: &1 + sign.read_period_seconds, else: &1))
    else
      sign
    end
  end

  defp send_audio(sign, audios) do
    sign.sign_updater.send_audio(
      sign.audio_id,
      Enum.map(audios, &Content.Audio.to_params(&1)),
      5,
      60,
      sign.id,
      Enum.map(audios, &Signs.Utilities.Audio.audio_log_details/1)
    )
  end
end
