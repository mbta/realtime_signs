defmodule Signs.Utilities.Updater do
  @moduledoc """
  Sends the update request for a sign if the new messages are different from
  what is currently on the sign. If they're both different, updates both lines
  at once, otherwise updates just the different line. If either line is "ARR"
  and the sign is configured to announce that fact, will send that audio request, too.
  """

  alias Signs.Utilities.Reader
  require Logger

  @spec update_sign(
          Signs.Realtime.t(),
          Signs.Realtime.line_content(),
          Signs.Realtime.line_content()
        ) :: Signs.Realtime.t()
  def update_sign(sign, {_top_src, top_msg} = top, {_bottom_src, bottom_msg} = bottom) do
    case {same_content?(sign.current_content_top, top),
          same_content?(sign.current_content_bottom, bottom)} do
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

        sign = %{sign | current_content_top: top}

        sign =
          if Signs.Utilities.Audio.should_interrupting_read?(top, sign, :top) do
            Reader.interrupting_read(sign)
          else
            sign
          end

        %{sign | current_content_top: top, tick_top: sign.expiration_seconds}

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

        sign = %{sign | current_content_bottom: bottom}

        sign =
          if Signs.Utilities.Audio.should_interrupting_read?(bottom, sign, :bottom) do
            Reader.interrupting_read(sign)
          else
            sign
          end

        %{sign | current_content_bottom: bottom, tick_bottom: sign.expiration_seconds}

      # update both
      {false, false} ->
        new_top_already_interrupting_read? =
          is_boarding_message?(top_msg) && same_content?(sign.current_content_bottom, top)

        log_line_update(sign, top_msg, "top")
        log_line_update(sign, bottom_msg, "bottom")

        sign.sign_updater.update_sign(
          sign.text_id,
          top_msg,
          bottom_msg,
          sign.expiration_seconds + 15,
          :now
        )

        sign = %{
          sign
          | current_content_top: top,
            current_content_bottom: bottom
        }

        sign =
          if !new_top_already_interrupting_read? &&
               (Signs.Utilities.Audio.should_interrupting_read?(top, sign, :top) ||
                  Signs.Utilities.Audio.should_interrupting_read?(
                    bottom,
                    sign,
                    :bottom
                  )) do
            Reader.interrupting_read(sign)
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
         %Content.Message.Predictions{headsign: same, minutes: :approaching}
       ) do
    true
  end

  defp countup?(
         %Content.Message.Predictions{headsign: same, minutes: :approaching},
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

  @spec is_boarding_message?(Content.Message.t()) :: boolean
  defp is_boarding_message?(msg) do
    case msg do
      %Content.Message.Predictions{minutes: :boarding} -> true
      _ -> false
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
end
