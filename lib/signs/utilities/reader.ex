defmodule Signs.Utilities.Reader do
  @moduledoc """
  Periodically sends audio requests to read the contents of the sign.
  If the headsign on the second line is different from the top line, will
  read that as well.
  """
  require Logger

  def read_sign(%{tick_read: n} = sign) when n > 0 do
    Logger.info("tick read: #{n}")
    sign
  end

  def read_sign(
        %{
          current_content_top: {_, %Content.Message.Headways.Top{} = top},
          current_content_bottom: {_, %Content.Message.Headways.Bottom{} = bottom}
        } = sign
      ) do
    Logger.info("sign read for headway sign: #{inspect(top)} #{inspect(bottom)}")

    send_audio_update({sign.source_config, sign.current_content_top}, sign)
    %{sign | tick_read: sign.read_period_seconds}
  end

  def read_sign(sign) do
    Logger.info("sign read for normal predictions:  ")

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
    Logger.info("this should happen at least sometimes")

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

    case Content.Audio.BusesToDestination.from_headway_message(sign, msg.headsign) do
      {%Content.Audio.BusesToDestination{} = audio, %Content.Audio.BusesToDestination{}} ->
        Logger.info("sent the audio for the headways")
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)

      {nil, nil} ->
        nil
    end
  end
end
