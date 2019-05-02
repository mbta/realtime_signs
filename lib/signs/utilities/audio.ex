defmodule Signs.Utilities.Audio do
  @moduledoc """
  Takes a sign and returns the audio struct or tuple of
  two audio structs to be sent to ARINC.
  """

  alias Content.Message
  alias Content.Audio
  alias Signs.Utilities.SourceConfig
  require Logger

  @announced_history_length 5

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
          %Content.Message.Predictions{minutes: arriving_or_approaching}
        },
        _config,
        _line
      )
      when arriving_or_approaching in [:arriving, :approaching] do
    false
  end

  def should_interrupting_read?(
        {
          %SourceConfig{announce_arriving?: true},
          %Content.Message.Predictions{minutes: arriving_or_approaching}
        },
        config,
        :bottom
      )
      when arriving_or_approaching in [:arriving, :approaching] do
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
    audio = get_audio(sign.current_content_top, sign.current_content_bottom, multi_source?)

    audio_list =
      case audio do
        as when is_tuple(as) -> Tuple.to_list(as)
        a -> List.wrap(a)
      end

    {new_audios, new_approaching_trips, new_arriving_trips} =
      Enum.reduce(
        audio_list,
        {[], sign.announced_approachings, sign.announced_arrivals},
        fn audio, {new_audios, new_approaching_trips, new_arriving_trips} ->
          case audio do
            %Audio.TrainIsArriving{trip_id: trip_id} when not is_nil(trip_id) ->
              if audio.trip_id in sign.announced_arrivals do
                {new_audios, new_approaching_trips, new_arriving_trips}
              else
                {new_audios ++ [audio], new_approaching_trips,
                 [audio.trip_id | new_arriving_trips]}
              end

            %Audio.Approaching{trip_id: trip_id} when not is_nil(trip_id) ->
              if audio.trip_id in sign.announced_approachings do
                {new_audios, new_approaching_trips, new_arriving_trips}
              else
                {new_audios ++ [audio], [audio.trip_id | new_approaching_trips],
                 new_arriving_trips}
              end

            _ ->
              {new_audios ++ [audio], new_approaching_trips, new_arriving_trips}
          end
        end
      )

    sign = %{
      sign
      | announced_approachings: Enum.take(new_approaching_trips, @announced_history_length),
        announced_arrivals: Enum.take(new_arriving_trips, @announced_history_length)
    }

    audio =
      case new_audios do
        [] -> nil
        [audio1] -> audio1
        [audio1, audio2] -> {audio1, audio2}
      end

    {audio, sign}
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
