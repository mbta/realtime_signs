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
          Signs.Realtime.line_content(),
          DateTime.t()
        ) :: Signs.Realtime.t()
  def update_sign(sign, top_msg, bottom_msg, current_time) do
    top_changed? = not Messages.same_content?(sign.current_content_top, top_msg)
    new_top = if top_changed?, do: top_msg, else: sign.current_content_top
    bottom_changed? = not Messages.same_content?(sign.current_content_bottom, bottom_msg)
    new_bottom = if bottom_changed?, do: bottom_msg, else: sign.current_content_bottom

    if top_changed?, do: log_line_update(sign, new_top, "top")
    if bottom_changed?, do: log_line_update(sign, new_bottom, "bottom")

    if !sign.last_update ||
         Timex.after?(current_time, Timex.shift(sign.last_update, seconds: 130)) ||
         top_changed? ||
         bottom_changed? do
      sign.sign_updater.update_sign(sign.text_id, new_top, new_bottom, 145, :now, sign.id)

      %{
        sign
        | current_content_top: new_top,
          current_content_bottom: new_bottom,
          last_update: current_time
      }
    else
      sign
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
