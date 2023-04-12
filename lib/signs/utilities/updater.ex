defmodule Signs.Utilities.Updater do
  @moduledoc """
  Sends the update request for a sign if the new messages are different from
  what is currently on the sign. If they're both different, updates both lines
  at once, otherwise updates just the different line. If either line is "ARR"
  and the sign is configured to announce that fact, will send that audio request, too.
  """

  alias Signs.Utilities.Messages
  require Logger

  @spec update_sign(
          Signs.Realtime.t(),
          Signs.Realtime.line_content(),
          Signs.Realtime.line_content()
        ) :: Signs.Realtime.t()
  def update_sign(
        sign,
        top_msg,
        bottom_msg
      ) do
    case {Messages.same_content?(sign.current_content_top, top_msg),
          Messages.same_content?(sign.current_content_bottom, bottom_msg)} do
      {true, true} ->
        sign

      # update top
      {false, true} ->
        log_line_update(sign, top_msg, "top")

        sign.sign_updater.update_single_line(
          sign.text_id,
          "1",
          top_msg,
          sign.expiration_seconds + 15,
          :now
        )

        %{sign | current_content_top: top_msg, tick_top: sign.expiration_seconds}

      # update bottom
      {true, false} ->
        log_line_update(sign, bottom_msg, "bottom")

        sign.sign_updater.update_single_line(
          sign.text_id,
          "2",
          bottom_msg,
          sign.expiration_seconds + 15,
          :now
        )

        %{sign | current_content_bottom: bottom_msg, tick_bottom: sign.expiration_seconds}

      # update both
      {false, false} ->
        log_line_update(sign, top_msg, "top")
        log_line_update(sign, bottom_msg, "bottom")

        sign.sign_updater.update_sign(
          sign.text_id,
          top_msg,
          bottom_msg,
          sign.expiration_seconds + 15,
          :now
        )

        %{
          sign
          | current_content_top: top_msg,
            current_content_bottom: bottom_msg,
            tick_top: sign.expiration_seconds,
            tick_bottom: sign.expiration_seconds
        }
    end
  end

  defp log_line_update(sign, msg, "top" = line) do
    case {sign, msg} do
      {%Signs.Realtime{id: sign_id, current_content_top: %Content.Message.Predictions{}},
       %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when msg_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=on")

      {%Signs.Realtime{
         id: sign_id,
         current_content_top: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
       }, %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when sign_stops_away == 0 and msg_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=on")

      {%Signs.Realtime{
         id: sign_id,
         current_content_top: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
       }, %Content.Message.Predictions{}}
      when sign_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=off")

      {%Signs.Realtime{
         id: sign_id,
         current_content_top: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
       }, %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when sign_stops_away > 0 and msg_stops_away == 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=off")

      _ ->
        :ok
    end
  end

  defp log_line_update(sign, msg, "bottom" = line) do
    case {sign, msg} do
      {%Signs.Realtime{id: sign_id, current_content_bottom: %Content.Message.Predictions{}},
       %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when msg_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=on")

      {%Signs.Realtime{
         id: sign_id,
         current_content_bottom: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
       }, %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when sign_stops_away == 0 and msg_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=on")

      {%Signs.Realtime{
         id: sign_id,
         current_content_bottom: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
       }, %Content.Message.Predictions{}}
      when sign_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=off")

      {%Signs.Realtime{
         id: sign_id,
         current_content_bottom: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
       }, %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when sign_stops_away > 0 and msg_stops_away == 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=off")

      _ ->
        :ok
    end
  end
end
