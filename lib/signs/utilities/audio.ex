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
  @spec should_interrupting_read?(
          Signs.Realtime.line_content(),
          SourceConfig.config(),
          Content.line()
        ) :: boolean()
  def should_interrupting_read?({_src, %Content.Message.Predictions{minutes: x}}, _config, _line)
      when is_integer(x) do
    false
  end

  def should_interrupting_read?(
        {
          %SourceConfig{announce_arriving?: false},
          %Content.Message.Predictions{minutes: :arriving}
        },
        _config,
        _line
      ) do
    false
  end

  def should_interrupting_read?(
        {
          %SourceConfig{announce_arriving?: true},
          %Content.Message.Predictions{minutes: :arriving}
        },
        config,
        :bottom
      ) do
    SourceConfig.multi_source?(config)
  end

  def should_interrupting_read?(
        {
          %SourceConfig{announce_boarding?: false},
          %Content.Message.Predictions{minutes: :boarding}
        },
        _config,
        _line
      ) do
    false
  end

  def should_interrupting_read?({_, %Content.Message.Empty{}}, _config, _line) do
    false
  end

  def should_interrupting_read?({_, %Content.Message.StoppedTrain{}}, _config, :bottom) do
    false
  end

  def should_interrupting_read?(_content, _config, _line) do
    true
  end

  @spec from_sign(Signs.Realtime.t()) ::
          {nil | Content.Audio.t() | {Content.Audio.t(), Content.Audio.t()}, Signs.Realtime.t()}
  def from_sign(sign) do
    multi_source? = Signs.Utilities.SourceConfig.multi_source?(sign.source_config)
    {get_audio(sign.current_content_top, sign.current_content_bottom, multi_source?), sign}
  end

  @spec get_audio(Signs.Realtime.line_content(), Signs.Realtime.line_content(), boolean()) ::
          nil | Content.Audio.t() | {Content.Audio.t(), Content.Audio.t()}
  defp get_audio(
         {_, %Message.Alert.NoService{} = top},
         {_, bottom},
         _multi_source?
       ) do
    Audio.Closure.from_messages(top, bottom)
  end

  defp get_audio(
         {_, %Message.Custom{} = top},
         {_, bottom},
         _multi_source?
       ) do
    Audio.Custom.from_messages(top, bottom)
  end

  defp get_audio(
         {_, top},
         {_, %Message.Custom{} = bottom},
         _multi_source?
       ) do
    Audio.Custom.from_messages(top, bottom)
  end

  defp get_audio(
         {_, %Message.Headways.Top{} = top},
         {_, bottom},
         _multi_source?
       ) do
    Audio.VehiclesToDestination.from_headway_message(top, bottom)
  end

  defp get_audio(
         {_, %Message.Predictions{minutes: :arriving}} = top_content,
         _bottom_content,
         _multi_source?
       ) do
    Audio.Predictions.from_sign_content(top_content, :top)
  end

  defp get_audio(
         {_, %Message.Predictions{headsign: same}} = content_top,
         {_, %Message.Predictions{headsign: same}} = content_bottom,
         _multi_source?
       ) do
    top_audio = Audio.Predictions.from_sign_content(content_top, :top)

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
         {_, %Message.StoppedTrain{headsign: same}},
         _multi_source?
       ) do
    Audio.StoppedTrain.from_message(top)
  end

  defp get_audio(
         {_, %Message.StoppedTrain{headsign: same} = top},
         {_, %Message.Predictions{headsign: same}},
         _multi_source?
       ) do
    Audio.StoppedTrain.from_message(top)
  end

  defp get_audio(
         {_, %Message.Predictions{headsign: same}} = top_content,
         {_, %Message.StoppedTrain{headsign: same}},
         _multi_source?
       ) do
    Audio.Predictions.from_sign_content(top_content, :top)
  end

  defp get_audio(top, bottom, _multi_source?) do
    top_audio = get_audio_for_line(top, :top)
    bottom_audio = get_audio_for_line(bottom, :bottom)
    normalize(top_audio, bottom_audio)
  end

  @spec get_audio_for_line(Signs.Realtime.line_content(), Content.line()) ::
          Content.Audio.t() | nil
  defp get_audio_for_line({_, %Message.StoppedTrain{} = message}, _line) do
    Audio.StoppedTrain.from_message(message)
  end

  defp get_audio_for_line({_, %Message.Predictions{}} = content, line) do
    Audio.Predictions.from_sign_content(content, line)
  end

  defp get_audio_for_line({_, %Message.Empty{}}, _line) do
    nil
  end

  defp get_audio_for_line(content, _line) do
    Logger.error("message_to_audio_error Utilities.Audio unknown_line #{inspect(content)}")
    nil
  end

  defp normalize(nil, nil), do: nil
  defp normalize(nil, a), do: a
  defp normalize(a, nil), do: a
  defp normalize(a1, a2), do: {a1, a2}
end
