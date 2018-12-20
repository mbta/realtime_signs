defmodule Signs.Utilities.Updater do
  @moduledoc """
  Sends the update request for a sign if the new messages are different from
  what is currently on the sign. If they're both different, updates both lines
  at once, otherwise updates just the different line. If either line is "ARR"
  and the sign is configured to announce that fact, will send that audio request, too.
  """

  alias Signs.Utilities.SourceConfig
  require Logger

  def update_sign(sign, {_top_src, top_msg} = top, {_bottom_src, bottom_msg} = bottom) do
    Logger.info("update_sign_messages: top: #{inspect(top_msg)} bottom: #{inspect(bottom_msg)}")

    sign =
      sign
      |> clear_announced_arrivals(sign.current_content_top, top)
      |> clear_announced_arrivals(sign.current_content_bottom, bottom)

    case {same_content?(sign.current_content_top, top),
          same_content?(sign.current_content_bottom, bottom)} do
      {true, true} ->
        sign

      # update top
      {false, true} ->
        log_line_update(sign, top_msg, "top")

        sign.sign_updater.update_single_line(
          sign.pa_ess_id,
          "1",
          top_msg,
          sign.expiration_seconds + 15,
          :now
        )

        sign = announce_arrival(top, sign)
        announce_track_change(top_msg, sign)
        sign = announce_stopped_train(top_msg, sign)

        %{sign | current_content_top: top, tick_top: sign.expiration_seconds}

      # update bottom
      {true, false} ->
        log_line_update(sign, bottom_msg, "bottom")

        sign.sign_updater.update_single_line(
          sign.pa_ess_id,
          "2",
          bottom_msg,
          sign.expiration_seconds + 15,
          :now
        )

        sign =
          if SourceConfig.multi_source?(sign.source_config) do
            sign = announce_arrival(bottom, sign)
            announce_track_change(bottom_msg, sign)
            announce_stopped_train(bottom_msg, sign)
          else
            sign
          end

        %{sign | current_content_bottom: bottom, tick_bottom: sign.expiration_seconds}

      # update both
      {false, false} ->
        log_line_update(sign, top_msg, "top")
        log_line_update(sign, bottom_msg, "bottom")

        sign.sign_updater.update_sign(
          sign.pa_ess_id,
          top_msg,
          bottom_msg,
          sign.expiration_seconds + 15,
          :now
        )

        sign = announce_arrival(top, sign)
        announce_track_change(top_msg, sign)
        sign = announce_stopped_train(top_msg, sign)

        sign =
          if SourceConfig.multi_source?(sign.source_config) do
            sign = announce_arrival(bottom, sign)
            announce_track_change(bottom_msg, sign)
            announce_stopped_train(bottom_msg, sign)
          else
            sign
          end

        %{
          sign
          | current_content_top: top,
            current_content_bottom: bottom,
            tick_top: sign.expiration_seconds,
            tick_bottom: sign.expiration_seconds
        }
    end
  end

  defp same_content?({_sign_src, sign_msg}, {_new_src, new_msg}) do
    sign_msg == new_msg or countup?(sign_msg, new_msg)
  end

  defp countup?(
         %Content.Message.Predictions{headsign: same, minutes: :arriving},
         %Content.Message.Predictions{headsign: same, minutes: 1}
       ) do
    true
  end

  defp countup?(
         %Content.Message.Predictions{headsign: same, minutes: a},
         %Content.Message.Predictions{headsign: same, minutes: b}
       )
       when a + 1 == b do
    true
  end

  defp countup?(_sign, _new) do
    false
  end

  defp log_line_update(sign, msg, "top" = line) do
    case {sign, msg} do
      {%Signs.Realtime{id: sign_id, current_content_top: {_, %Content.Message.Predictions{}}},
       %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when msg_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=on")

      {%Signs.Realtime{
         id: sign_id,
         current_content_top: {_, %Content.Message.StoppedTrain{stops_away: sign_stops_away}}
       }, %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when sign_stops_away == 0 and msg_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=on")

      {%Signs.Realtime{
         id: sign_id,
         current_content_top: {_, %Content.Message.StoppedTrain{stops_away: sign_stops_away}}
       }, %Content.Message.Predictions{}}
      when sign_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=off")

      {%Signs.Realtime{
         id: sign_id,
         current_content_top: {_, %Content.Message.StoppedTrain{stops_away: sign_stops_away}}
       }, %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when sign_stops_away > 0 and msg_stops_away == 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=off")

      _ ->
        :ok
    end
  end

  defp log_line_update(sign, msg, "bottom" = line) do
    case {sign, msg} do
      {%Signs.Realtime{id: sign_id, current_content_bottom: {_, %Content.Message.Predictions{}}},
       %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when msg_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=on")

      {%Signs.Realtime{
         id: sign_id,
         current_content_bottom: {_, %Content.Message.StoppedTrain{stops_away: sign_stops_away}}
       }, %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when sign_stops_away == 0 and msg_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=on")

      {%Signs.Realtime{
         id: sign_id,
         current_content_bottom: {_, %Content.Message.StoppedTrain{stops_away: sign_stops_away}}
       }, %Content.Message.Predictions{}}
      when sign_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=off")

      {%Signs.Realtime{
         id: sign_id,
         current_content_bottom: {_, %Content.Message.StoppedTrain{stops_away: sign_stops_away}}
       }, %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when sign_stops_away > 0 and msg_stops_away == 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=off")

      _ ->
        :ok
    end
  end

  defp announce_arrival({%SourceConfig{announce_arriving?: false}, _msg}, sign), do: sign

  defp announce_arrival({_src, msg}, sign) do
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
          %{sign | announced_arrivals: MapSet.put(sign.announced_arrivals, audio.destination)}
        end

      nil ->
        sign
    end
  end

  defp announce_stopped_train(msg, sign) do
    case Content.Audio.StoppedTrain.from_message(msg) do
      %Content.Audio.StoppedTrain{} = audio ->
        if sign.tick_read > 30 do
          sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
        end

        sign

      nil ->
        sign
    end
  end

  defp announce_track_change(msg, sign) do
    case Content.Audio.TrackChange.from_message(msg) do
      %Content.Audio.TrackChange{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)
        sign

      nil ->
        sign
    end
  end

  defp clear_announced_arrivals(
         sign,
         {_src, %Content.Message.Predictions{minutes: :boarding, headsign: hs}} = current_content,
         new_content
       )
       when current_content != new_content do
    case PaEss.Utilities.headsign_to_terminal_station(hs) do
      {:ok, terminal} ->
        %{sign | announced_arrivals: MapSet.delete(sign.announced_arrivals, terminal)}

      _ ->
        sign
    end
  end

  defp clear_announced_arrivals(
         sign,
         {_src, %Content.Message.StoppedTrain{headsign: hs}} = current_content,
         new_content
       )
       when current_content != new_content do
    case PaEss.Utilities.headsign_to_terminal_station(hs) do
      {:ok, terminal} ->
        %{sign | announced_arrivals: MapSet.delete(sign.announced_arrivals, terminal)}

      _ ->
        sign
    end
  end

  defp clear_announced_arrivals(sign, _old_msg, _new_msg) do
    sign
  end
end
