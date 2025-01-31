defmodule Signs.Utilities.Reader do
  @spec read_sign(Signs.Realtime.t(), [Message.t()]) :: Signs.Realtime.t()
  def read_sign(%{tick_read: 0} = sign, messages) do
    audios = Enum.flat_map(messages, &Message.to_audio(&1, length(messages) > 1))

    if audios != [] do
      Signs.Utilities.Audio.send_audio(sign, audios)
    end

    %{sign | tick_read: sign.read_period_seconds}
  end

  def read_sign(sign, _) do
    sign
  end

  @spec do_announcements(Signs.Realtime.t(), [Message.t()]) :: Signs.Realtime.t()
  def do_announcements(sign, messages) do
    {audios, sign} = Signs.Utilities.Audio.get_announcements(sign, messages)

    if audios != [] do
      Signs.Utilities.Audio.send_audio(sign, audios)
      update_in(sign.tick_read, &if(&1 < 120, do: &1 + sign.read_period_seconds, else: &1))
    else
      sign
    end
  end
end
