defmodule Signs.Utilities.Reader do
  @moduledoc """
  Periodically sends audio requests to read the contents of the sign.
  If the headsign on the second line is different from the top line, will
  read that as well.
  """

  require Logger

  @spec read_sign(Signs.Realtime.t() | Signs.Headway.t()) ::
          Signs.Realtime.t() | Signs.Headway.t()
  def read_sign(
        %{
          current_content_top: {_, %Content.Message.Headways.Top{}},
          current_content_bottom: {_, %Content.Message.Headways.Bottom{}}
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

    sign =
      if top_headsign do
        send_audio_update(sign.current_content_top, sign)
      else
        sign
      end

    bottom_headsign =
      case sign.current_content_bottom do
        {_src, %{headsign: headsign}} -> headsign
        _ -> nil
      end

    sign =
      if bottom_headsign && bottom_headsign != top_headsign do
        send_audio_update(sign.current_content_bottom, sign)
      else
        sign
      end

    sign =
      if top_headsign == nil && bottom_headsign == nil do
        send_audio_update(sign.current_content_top, sign)
      else
        sign
      end

    %{sign | tick_read: sign.read_period_seconds}
  end

  @spec send_audio_update(
          {Signs.Utilities.SourceConfig.source() | nil, Content.Message.t()},
          Signs.Realtime.t()
        ) :: Signs.Realtime.t()
  defp send_audio_update({src, msg}, sign) do
    sign =
      if Application.get_env(:realtime_signs, :static_text_enabled?) do
        case Content.Audio.Custom.from_messages(
               elem(sign.current_content_top, 1),
               elem(sign.current_content_bottom, 1)
             ) do
          %Content.Audio.Custom{} = audio ->
            sign.sign_updater.send_custom_audio(sign.pa_ess_id, audio, 5, 60)
            sign

          nil ->
            sign
        end
      else
        sign
      end

    sign =
      case Content.Audio.TrainIsArriving.from_predictions_message(msg) do
        %Content.Audio.TrainIsArriving{} = audio ->
          if MapSet.member?(sign.announced_arrivals, audio.destination) do
            unless match?(%Content.Message.Predictions{minutes: :boarding}, msg) do
              # Not a warning if ARR -> BRD
              Logger.warn("skipping_arriving_audio #{inspect(audio)} #{inspect(sign)}")
            end

            sign
          else
            sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)

            sign = %{
              sign
              | announced_arrivals: MapSet.put(sign.announced_arrivals, audio.destination)
            }

            sign
          end

        nil ->
          sign
      end

    sign =
      case Content.Audio.NextTrainCountdown.from_predictions_message(msg, src) do
        %Content.Audio.NextTrainCountdown{} = audio ->
          sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
          sign

        nil ->
          sign
      end

    sign =
      case Content.Audio.StoppedTrain.from_message(msg) do
        %Content.Audio.StoppedTrain{} = audio ->
          sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
          sign

        nil ->
          sign
      end

    sign =
      case Content.Audio.VehiclesToDestination.from_headway_message(
             elem(sign.current_content_bottom, 1),
             elem(sign.current_content_top, 1)
           ) do
        {%Content.Audio.VehiclesToDestination{language: :english} = english_audio,
         %Content.Audio.VehiclesToDestination{language: :spanish} = spanish_audio} ->
          sign.sign_updater.send_audio(sign.pa_ess_id, english_audio, 5, 60)
          sign.sign_updater.send_audio(sign.pa_ess_id, spanish_audio, 5, 60)

          sign

        {%Content.Audio.VehiclesToDestination{} = english_audio, nil} ->
          sign.sign_updater.send_audio(sign.pa_ess_id, english_audio, 5, 60)
          sign

        {nil, nil} ->
          sign
      end

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
           elem(sign.current_content_top, 1)
         ) do
      {%Content.Audio.VehiclesToDestination{language: :english} = english_audio,
       %Content.Audio.VehiclesToDestination{language: :spanish} = spanish_audio} ->
        sign.sign_updater.send_audio(sign.pa_ess_id, english_audio, 5, 60)
        sign.sign_updater.send_audio(sign.pa_ess_id, spanish_audio, 5, 60)

      {%Content.Audio.VehiclesToDestination{} = english_audio, nil} ->
        sign.sign_updater.send_audio(sign.pa_ess_id, english_audio, 5, 60)

      {nil, nil} ->
        nil
    end

    case Content.Audio.Closure.from_messages(
           elem(sign.current_content_top, 1),
           elem(sign.current_content_bottom, 1)
         ) do
      %Content.Audio.Closure{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)

      nil ->
        nil
    end
  end
end
