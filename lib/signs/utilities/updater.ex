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
    case {sign.current_content_top == top, sign.current_content_bottom == bottom} do
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

        announce_arrival(top, sign)
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
            announce_arrival(bottom, sign)
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

        announce_arrival(top, sign)

        sign = announce_stopped_train(top_msg, sign)

        sign =
          if SourceConfig.multi_source?(sign.source_config) do
            announce_arrival(bottom, sign)
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

  defp announce_arrival({%SourceConfig{announce_arriving?: false}, _msg}, _sign), do: nil

  defp announce_arrival({_src, msg}, sign) do
    case Content.Audio.TrainIsArriving.from_predictions_message(msg) do
      %Content.Audio.TrainIsArriving{} = audio ->
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)

      nil ->
        nil
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
end
