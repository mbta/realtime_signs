defmodule Signs.Utilities.Reader do
  @moduledoc """
  Periodically sends audio requests to read the contents of the sign.
  If the headsign on the second line is different from the top line, will
  read that as well.
  """
  require Logger

  def read_sign(%{tick_read: n} = sign) when n > 0 do
    sign
  end

  def read_sign(
        %{
          current_content_top: {_, %Content.Message.Headways.Top{} = top},
          current_content_bottom: {_, %Content.Message.Headways.Bottom{} = bottom}
        } = sign
      ) do
    send_audio_update(sign.current_content_top, sign)
    %{sign | tick_read: sign.read_period_seconds}
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
    case Content.Audio.NextTrainCountdown.from_predictions_message(msg, src) do
      %Content.Audio.NextTrainCountdown{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)

      nil ->
        nil
    end

    case Content.Audio.StoppedTrain.from_message(msg) do
      %Content.Audio.StoppedTrain{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)

      nil ->
        nil
    end

    case Content.Audio.VehiclesToDestination.from_headway_message(
           elem(sign.current_content_bottom, 1),
           msg.headsign
         ) do
      {%Content.Audio.VehiclesToDestination{} = audio, %Content.Audio.VehiclesToDestination{}} ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)

      {nil, nil} ->
        nil
    end
  end
end
