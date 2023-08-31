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
end
