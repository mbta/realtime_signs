defmodule Signs.Utilities.Reader do
  @moduledoc """
  Periodically sends audio requests to read the contents of the sign.
  If the headsign on the second line is different from the top line, will
  read that as well.
  """
  alias Signs.Utilities.Messages

  @spec read_sign(Signs.Realtime.t()) :: Signs.Realtime.t()
  def read_sign(%{tick_read: 0} = sign) do
    {_announced, sign} = send_audio_update(sign)

    %{sign | tick_read: sign.read_period_seconds}
  end

  def read_sign(sign) do
    sign
  end

  @spec do_interrupting_reads(
          atom
          | %{:current_content_bottom => any, :current_content_top => any, optional(any) => any},
          any,
          any
        ) ::
          atom
          | %{:current_content_bottom => any, :current_content_top => any, optional(any) => any}
  def do_interrupting_reads(
        sign,
        old_top,
        old_bottom
      ) do
    case {Messages.same_content?(old_top, sign.current_content_top),
          Messages.same_content?(old_bottom, sign.current_content_bottom)} do
      {true, true} ->
        sign

      # update top
      {false, true} ->
        if Signs.Utilities.Audio.should_interrupting_read?(sign.current_content_top, sign, :top) do
          interrupting_read(sign)
        else
          sign
        end

      # update bottom
      {true, false} ->
        if Signs.Utilities.Audio.should_interrupting_read?(
             sign.current_content_bottom,
             sign,
             :bottom
           ) do
          interrupting_read(sign)
        else
          sign
        end

      # update both
      {false, false} ->
        new_top_already_interrupting_read? =
          is_boarding_message?(sign.current_content_top) &&
            Messages.same_content?(old_bottom, sign.current_content_top)

        if !new_top_already_interrupting_read? &&
             (Signs.Utilities.Audio.should_interrupting_read?(
                sign.current_content_top,
                sign,
                :top
              ) ||
                Signs.Utilities.Audio.should_interrupting_read?(
                  sign.current_content_bottom,
                  sign,
                  :bottom
                )) do
          interrupting_read(sign)
        else
          sign
        end
    end
  end

  @spec interrupting_read(Signs.Realtime.t()) :: Signs.Realtime.t()
  def interrupting_read(%{tick_read: 0} = sign) do
    sign
  end

  def interrupting_read(sign) do
    case send_audio_update(sign) do
      {true, sign} ->
        if sign.tick_read < 120 do
          %{sign | tick_read: sign.tick_read + sign.read_period_seconds}
        else
          sign
        end

      {false, sign} ->
        sign
    end
  end

  @spec send_audio_update(Signs.Realtime.t()) :: {boolean(), Signs.Realtime.t()}
  defp send_audio_update(sign) do
    case Signs.Utilities.Audio.from_sign(sign) do
      {[], sign} ->
        {false, sign}

      {audios, sign} ->
        sign.sign_updater.send_audio(sign.audio_id, audios, 5, 60)
        {true, sign}
    end
  end

  @spec is_boarding_message?(Content.Message.t()) :: boolean
  defp is_boarding_message?(msg) do
    case msg do
      %Content.Message.Predictions{minutes: :boarding} -> true
      _ -> false
    end
  end
end
