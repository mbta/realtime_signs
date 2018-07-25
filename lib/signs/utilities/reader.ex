defmodule Signs.Utilities.Reader do
  @moduledoc """
  Periodically sends audio requests to read the contents of the sign.
  If the headsign on the second line is different from the top line, will
  read that as well.
  """

  def read_sign(%{tick_read: n} = sign) when n > 0 do
    sign
  end

  def read_sign(sign) do
    top_headsign =
      case sign.current_content_top do
        {_src, %{headsign: headsign}} -> headsign
        _ -> nil
      end

    if top_headsign do
      send_audio_update(sign.current_content_top, sign)
    end

    bottom_headsign =
      case sign.current_content_bottom do
        {_src, %{headsign: headsign}} -> headsign
        _ -> nil
      end

    if bottom_headsign && bottom_headsign != top_headsign do
      send_audio_update(sign.current_content_bottom, sign)
    end

    %{sign | tick_read: sign.read_period_seconds}
  end

  defp send_audio_update({src, msg}, sign) do
    verb = if src.terminal?, do: :departs, else: :arrives

    case Content.Audio.NextTrainCountdown.from_predictions_message(msg, verb, src.platform) do
      %Content.Audio.NextTrainCountdown{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)

      nil ->
        nil
    end
  end
end
