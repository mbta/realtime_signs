defmodule Signs.Utilities.Updater do
  @moduledoc """
  Sends the update request for a sign if the new messages are different from
  what is currently on the sign. If they're both different, updates both lines
  at once, otherwise updates just the different line. If either line is "ARR"
  and the sign is configured to announce that fact, will send that audio request, too.
  """

  alias Signs.Utilities.SourceConfig

  def update_sign(sign, {_top_src, top_msg} = top, {_bottom_src, bottom_msg} = bottom) do
    case {sign.current_content_top == top, sign.current_content_bottom == bottom} do
      {true, true} ->
        sign

      # update top
      {false, true} ->
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
        sign.sign_updater.update_single_line(
          sign.pa_ess_id,
          "2",
          bottom_msg,
          sign.expiration_seconds + 15,
          :now
        )

        announce_arrival(bottom, sign)

        sign =
          if different_headsigns?(top, bottom) do
            announce_stopped_train(bottom_msg, sign)
          else
            sign
          end

        %{sign | current_content_bottom: bottom, tick_bottom: sign.expiration_seconds}

      # update both
      {false, false} ->
        sign.sign_updater.update_sign(
          sign.pa_ess_id,
          top_msg,
          bottom_msg,
          sign.expiration_seconds + 15,
          :now
        )

        announce_arrival(top, sign)

        sign = announce_stopped_train(top_msg, sign)

        announce_arrival(bottom, sign)

        sign =
          if different_headsigns?(bottom, sign.current_content_bottom) do
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

  defp different_headsigns?({_src, %{headsign: same}}, {_src2, %{headsign: same}}), do: false
  defp different_headsigns?(_, _), do: true

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
        sign.sign_updater.send_audio(sign.pa_ess_id, audio, 5, 60)

        if sign.tick_read < 60 do
          %{sign | tick_read: sign.tick_read + sign.read_period_seconds}
        else
          sign
        end

      nil ->
        sign
    end
  end
end
