defmodule Signs.Utilities.Updater do
  @moduledoc """
  Sends the update request for a sign if the new messages are different from
  what is currently on the sign. If they're both different, updates both lines
  at once, otherwise updates just the different line. If either line is "ARR"
  and the sign is configured to announce that fact, will send that audio request, too.
  """

  require Logger

  @spec update_sign(
          Signs.Realtime.t(),
          Content.Message.value(),
          Content.Message.value(),
          DateTime.t()
        ) :: Signs.Realtime.t()
  def update_sign(sign, new_top, new_bottom, current_time) do
    if !sign.last_update ||
         Timex.after?(current_time, Timex.shift(sign.last_update, seconds: 130)) ||
         sign.current_content_top != new_top ||
         sign.current_content_bottom != new_bottom do
      RealtimeSigns.sign_updater().set_background_message(sign, new_top, new_bottom)

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
