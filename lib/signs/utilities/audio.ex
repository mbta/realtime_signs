defmodule Signs.Utilities.Audio do
  @moduledoc """
  Takes a sign and returns the audio struct or tuple of
  two audio structs to be sent to ARINC.
  """

  alias Signs.Utilities.SourceConfig
  require Logger

  @spec from_sign(Signs.Realtime.t()) ::
          nil | Content.Audio.t() | {Content.Audio.t(), Content.Audio.t()}
  def from_sign(sign) do
    {audio_list, sign} =
      case calculate_full_sign_audio(sign) do
        {[], sign} ->
          calculate_multiline_audio(sign)

        {audios, sign} ->
          {audios, sign}
      end

    case audio_list do
      [] -> {nil, sign}
      [a] -> {a, sign}
      [a1, a2] -> {{a1, a2}, sign}
    end
  end

  @spec calculate_full_sign_audio(Signs.Realtime.t()) :: {[Content.Audio.t()], Signs.Realtime.t()}
  defp calculate_full_sign_audio(sign) do
    {_top_src, top_msg} = sign.current_content_top
    {_bottom_src, bottom_msg} = sign.current_content_bottom

    {closed_audio, sign} = announce_closure(top_msg, bottom_msg, sign)
    {custom_audio, sign} = announce_custom_audio(top_msg, bottom_msg, sign)
    {headway_audio, sign} = announce_headways(top_msg, bottom_msg, sign)

    audios = closed_audio ++ custom_audio ++ headway_audio
    {audios, sign}
  end

  @spec calculate_multiline_audio(Signs.Realtime.t()) :: {[Content.Audio.t()], Signs.Realtime.t()}
  defp calculate_multiline_audio(sign) do
    {_top_src, top_msg} = sign.current_content_top
    {_bottom_src, bottom_msg} = sign.current_content_bottom

    {stopped_audio, sign} = announce_stopped_train(top_msg, sign)

    {track_change_top_audio, _sign} = announce_track_change(top_msg, sign)
    {track_change_bottom_audio, _sign} = announce_track_change(bottom_msg, sign)

    {multi_source_boarding_audio, sign} =
      if SourceConfig.multi_source?(sign.source_config) do
        {top_audio, sign} =
          if track_change_top_audio == [] do
            announce_boarding(sign.current_content_top, sign)
          else
            {[], sign}
          end

        {bottom_audio, sign} =
          if track_change_bottom_audio == [] do
            announce_boarding(sign.current_content_bottom, sign)
          else
            {[], sign}
          end

        {bottom_stopped_audio, sign} = announce_stopped_train(bottom_msg, sign)
        {top_audio ++ bottom_audio ++ bottom_stopped_audio, sign}
      else
        {[], sign}
      end

    {boarding_top_audio, sign} =
      if track_change_top_audio == [] do
        announce_boarding(sign.current_content_top, sign)
      else
        {[], sign}
      end

    {boarding_bottom_audio, sign} =
      if track_change_bottom_audio == [] do
        announce_boarding(sign.current_content_bottom, sign)
      else
        {[], sign}
      end

    {arrival_top_audio, sign} = announce_arrival(sign.current_content_top, sign)
    {arrival_bottom_audio, sign} = announce_arrival(sign.current_content_bottom, sign)

    {next_train_audio, sign} =
      announce_next_trains(sign.current_content_top, sign.current_content_bottom, sign)

    audios =
      boarding_top_audio ++
        track_change_top_audio ++
        boarding_bottom_audio ++
        track_change_bottom_audio ++
        multi_source_boarding_audio ++
        arrival_top_audio ++ arrival_bottom_audio ++ stopped_audio ++ next_train_audio

    {audios, sign}
  end

  @spec announce_next_trains(
          {Signs.Utilities.SourceConfig.source(), Content.Message.t()},
          {Signs.Utilities.SourceConfig.source(), Content.Message.t()},
          Signs.Realtime.t()
        ) :: {[Content.Audio.t()], Signs.Realtime.t()}
  defp announce_next_trains(
         {top_src, %{headsign: same_headsign, minutes: _top_minutes} = top_msg},
         {bottom_src, %{headsign: same_headsign, minutes: _bottom_minutes} = bottom_msg},
         sign
       ) do
    {next_train_audio, sign} =
      case Content.Audio.NextTrainCountdown.from_predictions_message(top_msg, top_src) do
        %Content.Audio.NextTrainCountdown{} = audio ->
          {[audio], sign}

        nil ->
          {[], sign}
      end

    {following_train_audio, sign} =
      case Content.Audio.FollowingTrain.from_predictions_message(bottom_msg, bottom_src) do
        %Content.Audio.FollowingTrain{} = audio ->
          {[audio], sign}

        nil ->
          {[], sign}
      end

    {next_train_audio ++ following_train_audio, sign}
  end

  defp announce_next_trains({top_src, top_msg}, {bottom_src, bottom_msg}, sign) do
    {top_audio, sign} =
      case Content.Audio.NextTrainCountdown.from_predictions_message(top_msg, top_src) do
        %Content.Audio.NextTrainCountdown{} = audio ->
          {[audio], sign}

        nil ->
          {[], sign}
      end

    {bottom_audio, sign} =
      case Content.Audio.NextTrainCountdown.from_predictions_message(bottom_msg, bottom_src) do
        %Content.Audio.NextTrainCountdown{} = audio ->
          {[audio], sign}

        nil ->
          {[], sign}
      end

    {top_audio ++ bottom_audio, sign}
  end

  @spec announce_arrival(
          {Signs.Utilities.SourceConfig.source(), Content.Message.t()},
          Signs.Realtime.t()
        ) :: {[Content.Audio.t()], Signs.Realtime.t()}
  defp announce_arrival({%SourceConfig{announce_arriving?: false}, _msg}, sign), do: {[], sign}

  defp announce_arrival({_src, msg}, sign) do
    case Content.Audio.TrainIsArriving.from_predictions_message(msg) do
      %Content.Audio.TrainIsArriving{} = audio ->
        if MapSet.member?(sign.announced_arrivals, audio.destination) do
          unless match?(%Content.Message.Predictions{minutes: :boarding}, msg) do
            # Not a warning if ARR -> BRD
            Logger.info("skipping_arriving_audio #{inspect(audio)} #{inspect(sign)}")
          end

          {[], sign}
        else
          {[audio],
           %{sign | announced_arrivals: MapSet.put(sign.announced_arrivals, audio.destination)}}
        end

      nil ->
        {[], sign}
    end
  end

  @spec announce_boarding({SourceConfig.source(), Content.Message.t()}, Signs.Realtime.t()) ::
          {[Content.Audio.t()], Signs.Realtime.t()}
  defp announce_boarding({%SourceConfig{announce_boarding?: false}, _msg}, sign), do: {[], sign}

  defp announce_boarding({_src, msg}, sign) do
    case Content.Audio.TrainIsBoarding.from_message(msg) do
      %Content.Audio.TrainIsBoarding{} = audio ->
        {[audio], sign}

      nil ->
        {[], sign}
    end
  end

  @spec announce_stopped_train(Content.Message.t(), Signs.Realtime.t()) ::
          {[Content.Audio.t()], Signs.Realtime.t()}
  defp announce_stopped_train(msg, sign) do
    case Content.Audio.StoppedTrain.from_message(msg) do
      %Content.Audio.StoppedTrain{} = audio ->
        {[audio], sign}

      nil ->
        {[], sign}
    end
  end

  @spec announce_track_change(Content.Message.t(), Signs.Realtime.t()) ::
          {[Content.Audio.t()], Signs.Realtime.t()}
  defp announce_track_change(msg, sign) do
    case Content.Audio.TrackChange.from_message(msg) do
      %Content.Audio.TrackChange{} = audio ->
        {[audio], sign}

      nil ->
        {[], sign}
    end
  end

  @spec announce_closure(Content.Message.t(), Content.Message.t(), Signs.Realtime.t()) ::
          {[Content.Audio.t()], Signs.Realtime.t()}
  defp announce_closure(top_msg, bottom_msg, sign) do
    case Content.Audio.Closure.from_messages(
           top_msg,
           bottom_msg
         ) do
      %Content.Audio.Closure{} = audio ->
        {[audio], sign}

      nil ->
        {[], sign}
    end
  end

  @spec announce_custom_audio(Content.Message.t(), Content.Message.t(), Signs.Realtime.t()) ::
          {[Content.Audio.t()], Signs.Realtime.t()}
  defp announce_custom_audio(top_msg, bottom_msg, sign) do
    if Application.get_env(:realtime_signs, :static_text_enabled?) do
      case Content.Audio.Custom.from_messages(
             top_msg,
             bottom_msg
           ) do
        %Content.Audio.Custom{} = audio ->
          {[audio], sign}

        nil ->
          {[], sign}
      end
    else
      {[], sign}
    end
  end

  @spec announce_headways(Content.Message.t(), Content.Message.t(), Signs.Realtime.t()) ::
          {[Content.Audio.t()], Signs.Realtime.t()}
  defp announce_headways(top_msg, bottom_msg, sign) do
    case Content.Audio.VehiclesToDestination.from_headway_message(
           bottom_msg,
           top_msg
         ) do
      {%Content.Audio.VehiclesToDestination{language: :english} = english_audio,
       %Content.Audio.VehiclesToDestination{language: :spanish} = spanish_audio} ->
        {[english_audio, spanish_audio], sign}

      {%Content.Audio.VehiclesToDestination{} = english_audio, nil} ->
        {[english_audio], sign}

      {nil, nil} ->
        {[], sign}
    end
  end
end
