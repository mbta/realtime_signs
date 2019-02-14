defmodule Signs.Utilities.Reader do
  @moduledoc """
  Periodically sends audio requests to read the contents of the sign.
  If the headsign on the second line is different from the top line, will
  read that as well.
  """

  alias Signs.Utilities.SourceConfig
  require Logger

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
        if sign.tick_read < 60 do
          %{sign | tick_read: sign.tick_read + sign.read_period_seconds}
        else
          sign
        end

      {false, sign} ->
        sign
    end
  end

  @spec send_audio_update(Signs.Realtime.t()) :: {boolean, Signs.Realtime.t()}
  defp send_audio_update(sign) do
    {_top_src, top_msg} = sign.current_content_top
    {_bottom_src, bottom_msg} = sign.current_content_bottom

    {announced_closed?, sign} =
      case Content.Audio.Closure.from_messages(
             top_msg,
             bottom_msg
           ) do
        %Content.Audio.Closure{} = audio ->
          sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
          {true, sign}

        nil ->
          {false, sign}
      end

    {announced_custom?, sign} =
      if Application.get_env(:realtime_signs, :static_text_enabled?) do
        case Content.Audio.Custom.from_messages(
               top_msg,
               bottom_msg
             ) do
          %Content.Audio.Custom{} = audio ->
            sign.sign_updater.send_custom_audio(sign.pa_ess_id, audio, 5, 60)
            {true, sign}

          nil ->
            {false, sign}
        end
      else
        {false, sign}
      end

    {announced_headway?, sign} =
      case Content.Audio.VehiclesToDestination.from_headway_message(
             bottom_msg,
             top_msg
           ) do
        {%Content.Audio.VehiclesToDestination{language: :english} = english_audio,
         %Content.Audio.VehiclesToDestination{language: :spanish} = spanish_audio} ->
          sign.sign_updater.send_audio(sign.pa_ess_id, english_audio, 5, 60)
          sign.sign_updater.send_audio(sign.pa_ess_id, spanish_audio, 5, 60)

          {true, sign}

        {%Content.Audio.VehiclesToDestination{} = english_audio, nil} ->
          sign.sign_updater.send_audio(sign.pa_ess_id, english_audio, 5, 60)
          {true, sign}

        {nil, nil} ->
          {false, sign}
      end

    {announced_stopped?, sign} = announce_stopped_train(top_msg, sign)

    {announced_track_change_top?, _sign} = announce_track_change(top_msg, sign)
    {announced_track_change_bottom?, _sign} = announce_track_change(bottom_msg, sign)

    {announced_multi_source_boarding?, sign} =
      if SourceConfig.multi_source?(sign.source_config) do
        {announced_top?, sign} =
          if !announced_track_change_top? do
            announce_boarding(sign.current_content_top, sign)
          else
            {false, sign}
          end

        {announced_bottom?, sign} =
          if !announced_track_change_bottom? do
            announce_boarding(sign.current_content_bottom, sign)
          else
            {false, sign}
          end

        {announced_bottom_stopped?, sign} = announce_stopped_train(bottom_msg, sign)
        {announced_top? || announced_bottom? || announced_bottom_stopped?, sign}
      else
        {false, sign}
      end

    {announced_boarding_top?, sign} =
      if !announced_track_change_top? do
        announce_boarding(sign.current_content_top, sign)
      else
        {false, sign}
      end

    {announced_boarding_bottom?, sign} =
      if !announced_track_change_bottom? do
        announce_boarding(sign.current_content_bottom, sign)
      else
        {false, sign}
      end

    {announced_arrival_top?, sign} = announce_arrival(sign.current_content_top, sign)
    {announced_arrival_bottom?, sign} = announce_arrival(sign.current_content_bottom, sign)

    {announced_next_train?, sign} =
      announce_next_trains(sign.current_content_top, sign.current_content_bottom, sign)

    announced? =
      announced_next_train? || announced_arrival_top? || announced_arrival_bottom? ||
        announced_track_change_top? || announced_track_change_bottom? || announced_stopped? ||
        announced_multi_source_boarding? || announced_boarding_top? || announced_boarding_bottom? ||
        announced_closed? || announced_custom? || announced_headway?

    {announced?, sign}
  end

  @spec announce_next_trains(
          {Signs.Utilities.SourceConfig.source(), Content.Message.t()},
          {Signs.Utilities.SourceConfig.source(), Content.Message.t()},
          Signs.Realtime.t()
        ) :: {boolean, Signs.Realtime.t()}
  defp announce_next_trains(
         {top_src, %{headsign: same_headsign, minutes: _top_minutes} = top_msg},
         {_bottom_src, %{headsign: same_headsign, minutes: _bottom_minutes} = _bottom_msg},
         sign
       ) do
    {announced_next_train?, sign} =
      case Content.Audio.NextTrainCountdown.from_predictions_message(top_msg, top_src) do
        %Content.Audio.NextTrainCountdown{} = audio ->
          sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
          {true, sign}

        nil ->
          {false, sign}
      end

    {announced_next_train?, sign}
  end

  defp announce_next_trains({top_src, top_msg}, {bottom_src, bottom_msg}, sign) do
    {announced_top?, sign} =
      case Content.Audio.NextTrainCountdown.from_predictions_message(top_msg, top_src) do
        %Content.Audio.NextTrainCountdown{} = audio ->
          sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)

          {true, sign}

        nil ->
          {false, sign}
      end

    {announced_bottom?, sign} =
      case Content.Audio.NextTrainCountdown.from_predictions_message(bottom_msg, bottom_src) do
        %Content.Audio.NextTrainCountdown{} = audio ->
          sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
          {true, sign}

        nil ->
          {false, sign}
      end

    {announced_top? || announced_bottom?, sign}
  end

  @spec announce_arrival(
          {Signs.Utilities.SourceConfig.source(), Content.Message.t()},
          Signs.Realtime.t()
        ) :: {boolean, Signs.Realtime.t()}
  defp announce_arrival({%SourceConfig{announce_arriving?: false}, _msg}, sign), do: {false, sign}

  defp announce_arrival({_src, msg}, sign) do
    case Content.Audio.TrainIsArriving.from_predictions_message(msg) do
      %Content.Audio.TrainIsArriving{} = audio ->
        if MapSet.member?(sign.announced_arrivals, audio.destination) do
          unless match?(%Content.Message.Predictions{minutes: :boarding}, msg) do
            # Not a warning if ARR -> BRD
            Logger.info("skipping_arriving_audio #{inspect(audio)} #{inspect(sign)}")
          end

          {false, sign}
        else
          sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)

          {true,
           %{sign | announced_arrivals: MapSet.put(sign.announced_arrivals, audio.destination)}}
        end

      nil ->
        {false, sign}
    end
  end

  @spec announce_boarding({SourceConfig.source(), Content.Message.t()}, Signs.Realtime.t()) ::
          {boolean, Signs.Realtime.t()}
  defp announce_boarding({%SourceConfig{announce_boarding?: false}, _msg}, sign),
    do: {false, sign}

  defp announce_boarding({_src, msg}, sign) do
    case Content.Audio.TrainIsBoarding.from_message(msg) do
      %Content.Audio.TrainIsBoarding{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
        {true, sign}

      nil ->
        {false, sign}
    end
  end

  @spec announce_stopped_train(Content.Message.t(), Signs.Realtime.t()) ::
          {boolean, Signs.Realtime.t()}
  defp announce_stopped_train(msg, sign) do
    case Content.Audio.StoppedTrain.from_message(msg) do
      %Content.Audio.StoppedTrain{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)

        {true, sign}

      nil ->
        {false, sign}
    end
  end

  @spec announce_track_change(Content.Message.t(), Signs.Realtime.t()) ::
          {boolean(), Signs.Realtime.t()}
  defp announce_track_change(msg, sign) do
    case Content.Audio.TrackChange.from_message(msg) do
      %Content.Audio.TrackChange{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
        {true, sign}

      nil ->
        {false, sign}
    end
  end
end
