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
      {false, true} -> # update top
        sign.sign_updater.update_single_line(sign.pa_ess_id, "1", top_msg, sign.expiration_seconds + 15, :now)
        announce_arrival(top, sign)
        %{sign | current_content_top: top, tick_top: sign.expiration_seconds}
      {true, false} -> # update bottom
        sign.sign_updater.update_single_line(sign.pa_ess_id, "2", bottom_msg, sign.expiration_seconds + 15, :now)
        announce_arrival(bottom, sign)
        %{sign | current_content_bottom: bottom, tick_bottom: sign.expiration_seconds}
      {false, false} -> # update both
        sign.sign_updater.update_sign(sign.pa_ess_id, top_msg, bottom_msg, sign.expiration_seconds + 15, :now)
        announce_arrival(top, sign)
        announce_arrival(bottom, sign)
        %{sign | current_content_top: top, current_content_bottom: bottom, tick_top: sign.expiration_seconds, tick_bottom: sign.expiration_seconds}
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
end
