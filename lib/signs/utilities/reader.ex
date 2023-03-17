defmodule Signs.Utilities.Reader do
  @moduledoc """
  Periodically sends audio requests to read the contents of the sign.
  If the headsign on the second line is different from the top line, will
  read that as well.
  """

  @spec read_sign(Signs.Realtime.t()) :: Signs.Realtime.t()
  def read_sign(%{tick_read: 0} = sign) do
    {_announced, sign} = send_audio_update(sign)

    %{sign | tick_read: sign.read_period_seconds}
  end

  def read_sign(sign) do
    sign
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

  defp send_audio_update(sign) do
    if sign.extra_audio_content != [] do
      all_content = [
        {sign.current_content_top, sign.current_content_bottom} | sign.extra_audio_content
      ]

      top_stopped_trains =
        for {{_, top_content} = top, _bottom} <- all_content,
            is_struct(top_content, Content.Message.StoppedTrain) do
          top
        end

      bottom_stopped_trains =
        for {_, {_, bottom_content} = bottom} <- all_content,
            is_struct(bottom_content, Content.Message.StoppedTrain) do
          bottom
        end

      predictions =
        Enum.reduce(all_content, [], fn {{_, top_content} = top, {_, bottom_content} = bottom},
                                        predictions ->
          predictions =
            if is_struct(top_content, Content.Message.Predictions),
              do: [top | predictions],
              else: predictions

          if is_struct(bottom_content, Content.Message.Predictions),
            do: [bottom | predictions],
            else: predictions
        end)
        |> Enum.sort_by(fn {_, prediction} ->
          case prediction.minutes do
            :boarding -> -3
            :arriving -> -2
            :approaching -> -1
            minutes when is_integer(minutes) -> minutes
            :max_time -> 1000
          end
        end)

      headways =
        for {{_, top_content} = top, {_, bottom_content} = bottom} <- all_content,
            is_struct(
              top_content,
              Content.Message.Headways.Top
            ) and
              is_struct(
                bottom_content,
                Content.Message.Headways.Bottom
              ) do
          {top, bottom}
        end

      paging_headways =
        for {_, {_, bottom_content} = bottom} <- all_content,
            is_struct(
              bottom_content,
              Content.Message.Headways.Paging
            ) do
          bottom
        end

      sorted_content =
        top_stopped_trains ++ predictions ++ bottom_stopped_trains ++ paging_headways ++ headways

      Signs.Utilities.Audio.from_content_list(sorted_content)
      |> then(fn audios -> send_audios(sign, audios) end)

      {true, sign}
    else
      case Signs.Utilities.Audio.from_sign(sign) do
        {nil, sign} ->
          {false, sign}

        {audios, sign} ->
          send_audios(sign, audios)
          {true, sign}
      end
    end
  end

  @spec send_audios(
          Signs.Realtime.t(),
          Content.Audio.t() | {Content.Audio.t(), Content.Audio.t()}
        ) :: {:ok, :sent} | {:error, any()}
  defp send_audios(sign, audio) do
    sign.sign_updater.send_audio(sign.audio_id, audio, 5, 60)
  end
end
