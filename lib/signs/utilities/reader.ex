defmodule Signs.Utilities.Reader do
  @moduledoc """
  Periodically sends audio requests to read the contents of the sign.
  If the headsign on the second line is different from the top line, will
  read that as well.
  """

  @spec read_sign(Signs.Realtime.t()) :: Signs.Realtime.t()
  def read_sign(%{tick_read: 0} = sign) do
    {_announced, sign} = send_audio_update(sign)

    %{sign | tick_read: sign.read_period_seconds}
  end

  def read_sign(sign) do
    sign
  end

  @spec interrupting_read(Signs.Realtime.t()) :: Signs.Realtime.t()
  def interrupting_read(%{tick_read: 0} = sign) do
    sign
  end

  def interrupting_read(sign) do
    case send_audio_update(sign) do
      {true, sign} ->
        if sign.tick_read < 120 do
          %{sign | tick_read: sign.tick_read + sign.read_period_seconds}
        else
          sign
        end

      {false, sign} ->
        sign
    end
  end

  @spec send_audio_update(Signs.Realtime.t()) :: {boolean(), Signs.Realtime.t()}
  defp send_audio_update(sign) do
    case Signs.Utilities.Audio.from_sign(sign) do
      {nil, sign} ->
        {false, sign}

      {audios, sign} ->
        send_audios(sign, audios)
        {true, sign}
    end
  end

  @spec send_audios(
          Signs.Realtime.t(),
          Content.Audio.t() | {Content.Audio.t(), Content.Audio.t()}
        ) :: {:ok, :sent} | {:error, any()}
  defp send_audios(sign, %Content.Audio.Custom{} = audio) do
    sign.sign_updater.send_custom_audio(sign.pa_ess_id, audio, 5, 60)
  end

  defp send_audios(sign, {audio1, audio2}) do
    sign.sign_updater.send_audio(sign.pa_ess_id, {audio1, audio2}, 5, 60)
  end

  defp send_audios(sign, audio) do
    sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
  end
end
