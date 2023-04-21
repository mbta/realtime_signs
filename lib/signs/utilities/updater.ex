defmodule Signs.Utilities.Updater do
  @moduledoc """
  Sends the update request for a sign if the new messages are different from
  what is currently on the sign. If they're both different, updates both lines
  at once, otherwise updates just the different line. If either line is "ARR"
  and the sign is configured to announce that fact, will send that audio request, too.
  """

  alias Signs.Utilities.Messages
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
    case Messages.same_content?(sign.current_content_top, top_msg) and
           Messages.same_content?(sign.current_content_bottom, bottom_msg) do
      true ->
        sign

      _ ->
        top_msg =
          if Messages.same_content?(sign.current_content_top, top_msg) do
            sign.current_content_top
          else
            log_line_update(sign, top_msg, "top")
            top_msg
          end

        bottom_msg =
          if Messages.same_content?(sign.current_content_bottom, bottom_msg) do
            sign.current_content_bottom
          else
            log_line_update(sign, bottom_msg, "bottom")
            bottom_msg
          end

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
            tick_content: sign.expiration_seconds
        }
    end
  end

  defp log_line_update(sign, msg, "top" = line) do
    case {sign, msg} do
      {%Signs.Realtime{id: sign_id, current_content_top: %Content.Message.Predictions{}},
      {%Signs.Realtime{id: sign_id, current_content_top: %Content.Message.Predictions{}},
       %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when msg_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=on")

      {%Signs.Realtime{
         id: sign_id,
         current_content_top: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
         current_content_top: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
       }, %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when sign_stops_away == 0 and msg_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=on")

      {%Signs.Realtime{
         id: sign_id,
         current_content_top: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
         current_content_top: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
       }, %Content.Message.Predictions{}}
      when sign_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=off")

      {%Signs.Realtime{
         id: sign_id,
         current_content_top: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
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
         current_content_bottom: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
       }, %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when sign_stops_away == 0 and msg_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=on")

      {%Signs.Realtime{
         id: sign_id,
         current_content_bottom: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
         current_content_bottom: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
       }, %Content.Message.Predictions{}}
      when sign_stops_away > 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=off")

      {%Signs.Realtime{
         id: sign_id,
         current_content_bottom: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
         current_content_bottom: %Content.Message.StoppedTrain{stops_away: sign_stops_away}
       }, %Content.Message.StoppedTrain{stops_away: msg_stops_away}}
      when sign_stops_away > 0 and msg_stops_away == 0 ->
        Logger.info("sign_id=#{sign_id} line=#{line} status=off")

      _ ->
        :ok
    end
  end
end
