defmodule Signs.Utilities.Audio do
  @moduledoc """
  Takes a sign and returns the audio struct or tuple of
  two audio structs to be sent to ARINC.
  """

  alias Content.Message
  alias Content.Audio
  alias Signs.Utilities.SourceConfig
  require Logger

  @doc "Takes a changed line, and returns if it should read immediately"
  @spec should_interrupting_read?(Signs.Realtime.line_content(), :top | :bottom) :: boolean()
  def should_interrupting_read?({_src, %Content.Message.Predictions{minutes: x}}, _line)
      when is_integer(x) do
    false
  end

  def should_interrupting_read?(
        {
          %SourceConfig{announce_arriving?: false},
          %Content.Message.Predictions{minutes: :arriving}
        },
        _line
      ) do
    false
  end

  def should_interrupting_read?(
        {
          %SourceConfig{announce_boarding?: false},
          %Content.Message.Predictions{minutes: :boarding}
        },
        _line
      ) do
    false
  end

  def should_interrupting_read?({_, %Content.Message.Empty{}}, _line) do
    false
  end

  def should_interrupting_read?({_, %Content.Message.StoppedTrain{}}, :bottom) do
    false
  end

  def should_interrupting_read?(_content, _line) do
    true
  end

  @spec from_sign(Signs.Realtime.t()) ::
          {nil | Content.Audio.t() | {Content.Audio.t(), Content.Audio.t()}, Signs.Realtime.t()}
  def from_sign(sign) do
    {get_audio(sign.current_content_top, sign.current_content_bottom), sign}
  end

  @spec get_audio(Signs.Realtime.line_content(), Signs.Realtime.line_content()) ::
          nil | Content.Audio.t() | {Content.Audio.t(), Content.Audio.t()}
  defp get_audio(
         {_, %Message.Alert.NoService{} = top},
         {_, bottom}
       ) do
    Audio.Closure.from_messages(top, bottom)
  end

  defp get_audio(
         {_, %Message.Custom{} = top},
         {_, bottom}
       ) do
    Audio.Custom.from_messages(top, bottom)
  end

  defp get_audio(
         {_, top},
         {_, %Message.Custom{} = bottom}
       ) do
    Audio.Custom.from_messages(top, bottom)
  end

  defp get_audio(
         {_, %Message.Headways.Top{} = top},
         {_, bottom}
       ) do
    Audio.VehiclesToDestination.from_headway_message(top, bottom)
  end

  defp get_audio(
         {_, %Message.Predictions{headsign: same}} = content_top,
         {_, %Message.Predictions{headsign: same}} = content_bottom
       ) do
    top_audio = Audio.Predictions.from_sign_content(content_top)

    if top_audio do
      case Audio.FollowingTrain.from_predictions_message(content_bottom) do
        nil -> top_audio
        bottom_audio -> {top_audio, bottom_audio}
      end
    else
      Logger.error(
        "message_to_audio_error Utilities.Audio same_headsign #{inspect(content_top)}, #{
          inspect(content_bottom)
        }"
      )

      nil
    end
  end

  defp get_audio(
         {_, %Message.StoppedTrain{headsign: same} = top},
         {_, %Message.StoppedTrain{headsign: same}}
       ) do
    Audio.StoppedTrain.from_message(top)
  end

  defp get_audio(
         {_, %Message.StoppedTrain{headsign: same} = top},
         {_, %Message.Predictions{headsign: same}}
       ) do
    Audio.StoppedTrain.from_message(top)
  end

  defp get_audio(
         {_, %Message.Predictions{headsign: same}} = top_content,
         {_, %Message.StoppedTrain{headsign: same}}
       ) do
    Audio.Predictions.from_sign_content(top_content)
  end

  defp get_audio(top, bottom) do
    top_audio = get_audio_for_line(top)
    bottom_audio = get_audio_for_line(bottom)
    normalize(top_audio, bottom_audio)
  end

  defp get_audio_for_line({_, %Message.StoppedTrain{} = message}) do
    Audio.StoppedTrain.from_message(message)
  end

  defp get_audio_for_line({_, %Message.Predictions{}} = content) do
    Audio.Predictions.from_sign_content(content)
  end

  defp get_audio_for_line({_, %Message.Empty{}}) do
    nil
  end

  defp get_audio_for_line(content) do
    Logger.error("message_to_audio_error Utilities.Audio unknown_line #{inspect(content)}")
    nil
  end

  defp normalize(nil, nil), do: nil
  defp normalize(nil, a), do: a
  defp normalize(a, nil), do: a
  defp normalize(a1, a2), do: {a1, a2}
end
