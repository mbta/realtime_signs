defmodule Signs.Utilities.Audio do
  @moduledoc """
  Takes a sign and returns the list of audio structs to be sent to ARINC.
  """

  alias Content.Message
  alias Content.Audio
  alias Signs.Utilities.SourceConfig
  require Logger

  @announced_history_length 5
  @heavy_rail_routes ["Red", "Orange", "Blue"]

  @doc "Takes a changed line, and returns if it should read immediately"
  @spec should_interrupting_read?(
          Signs.Realtime.line_content(),
          Signs.Realtime.t(),
          Content.line_location()
        ) :: boolean()
  def should_interrupting_read?({_src, %Content.Message.Predictions{minutes: x}}, _sign, _line)
      when is_integer(x) do
    false
  end

  def should_interrupting_read?(
        {
          %SourceConfig{announce_arriving?: false},
          %Content.Message.Predictions{minutes: arriving_or_approaching}
        },
        _sign,
        _line
      )
      when arriving_or_approaching in [:arriving, :approaching] do
    false
  end

  def should_interrupting_read?(
        {_src, %Content.Message.Predictions{minutes: :approaching, route_id: route_id}},
        _sign,
        _line
      )
      when route_id not in @heavy_rail_routes do
    false
  end

  def should_interrupting_read?(
        {
          %SourceConfig{announce_arriving?: true},
          %Content.Message.Predictions{minutes: arriving_or_approaching}
        },
        %Signs.Realtime{source_config: config},
        :bottom
      )
      when arriving_or_approaching in [:arriving, :approaching] do
    SourceConfig.multi_source?(config)
  end

  def should_interrupting_read?(
        {
          %SourceConfig{announce_boarding?: false},
          %Content.Message.Predictions{minutes: :boarding, trip_id: trip_id}
        },
        %Signs.Realtime{id: sign_id, announced_arrivals: announced_arrivals},
        _line
      ) do
    if trip_id not in announced_arrivals do
      Logger.info(
        "announced_brd_when_arr_skipped trip_id=#{inspect(trip_id)} sign_id=#{inspect(sign_id)}"
      )

      true
    else
      false
    end
  end

  def should_interrupting_read?({_, %Content.Message.Empty{}}, _sign, _line) do
    false
  end

  def should_interrupting_read?({_, %Content.Message.StoppedTrain{}}, _sign, :bottom) do
    false
  end

  def should_interrupting_read?({_, %Content.Message.Headways.Bottom{}}, _sign, _line) do
    false
  end

  def should_interrupting_read?({_, %Content.Message.Headways.Paging{}}, _sign, _line) do
    false
  end

  def should_interrupting_read?({_, %Content.Message.Alert.NoServiceUseShuttle{}}, _sign, _line) do
    false
  end

  def should_interrupting_read?({_, %Content.Message.Alert.DestinationNoService{}}, _sign, _line) do
    false
  end

  def should_interrupting_read?(_content, _sign, _line) do
    true
  end

  @spec from_sign(Signs.Realtime.t()) :: {[Content.Audio.t()], Signs.Realtime.t()}
  def from_sign(sign) do
    multi_source? = SourceConfig.multi_source?(sign.source_config)

    audios = get_audio(sign.current_content_top, sign.current_content_bottom, multi_source?)

    {new_audios, new_approaching_trips, new_arriving_trips} =
      Enum.reduce(
        audios,
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

    new_audios =
      if SourceConfig.multi_source?(sign.source_config) do
        sort_audio(new_audios)
      else
        new_audios
      end

    {new_audios, sign}
  end

  @spec sort_audio([Content.Audio.t()]) :: [Content.Audio.t()]
  defp sort_audio(audios) do
    Enum.sort_by(audios, fn audio ->
      case audio do
        %Content.Audio.TrainIsBoarding{} -> 1
        %Content.Audio.TrainIsArriving{} -> 2
        %Content.Audio.Approaching{} -> 3
        _ -> 4
      end
    end)
  end

  @spec get_audio(Signs.Realtime.line_content(), Signs.Realtime.line_content(), boolean()) ::
          [Content.Audio.t()]
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
         {_, %Message.Predictions{minutes: :arriving, route_id: route_id}} = top_content,
         _bottom_content,
         multi_source?
       )
       when route_id in @heavy_rail_routes do
    Audio.Predictions.from_sign_content(top_content, :top, multi_source?)
  end

  defp get_audio(
         _top_content,
         {_, %Message.Predictions{minutes: :arriving, route_id: route_id}} = bottom_content,
         multi_source?
       )
       when multi_source? and route_id in @heavy_rail_routes do
    Audio.Predictions.from_sign_content(bottom_content, :bottom, multi_source?)
  end

  defp get_audio(
         {_, %Message.Predictions{destination: same}} = content_top,
         {_, %Message.Predictions{destination: same}} = content_bottom,
         multi_source?
       ) do
    Audio.Predictions.from_sign_content(content_top, :top, multi_source?) ++
      Audio.FollowingTrain.from_predictions_message(content_bottom)
  end

  defp get_audio(
         {_, %Message.StoppedTrain{destination: same} = top},
         {_, %Message.StoppedTrain{destination: same}},
         _multi_source?
       ) do
    Audio.StoppedTrain.from_message(top)
  end

  defp get_audio(
         {_, %Message.StoppedTrain{destination: same} = top},
         {_, %Message.Predictions{destination: same}},
         _multi_source?
       ) do
    Audio.StoppedTrain.from_message(top)
  end

  defp get_audio(
         {_, %Message.Predictions{destination: same}} = top_content,
         {_, %Message.StoppedTrain{destination: same}},
         multi_source?
       ) do
    Audio.Predictions.from_sign_content(top_content, :top, multi_source?)
  end

  defp get_audio(top, bottom, multi_source?) do
    get_audio_for_line(top, :top, multi_source?) ++
      get_audio_for_line(bottom, :bottom, multi_source?)
  end

  @spec get_audio_for_line(Signs.Realtime.line_content(), Content.line_location(), boolean()) ::
          [Content.Audio.t()]
  defp get_audio_for_line({_, %Message.StoppedTrain{} = message}, _line, _multi_source?) do
    Audio.StoppedTrain.from_message(message)
  end

  defp get_audio_for_line({_, %Message.Predictions{}} = content, line, multi_source?) do
    Audio.Predictions.from_sign_content(content, line, multi_source?)
  end

  defp get_audio_for_line({_, %Message.Headways.Paging{} = message}, _line, _multi_source?) do
    Audio.VehiclesToDestination.from_paging_headway_message(message)
  end

  defp get_audio_for_line(
         {_, %Message.Alert.DestinationNoService{} = message},
         _line,
         _multi_source?
       ) do
    Audio.NoServiceToDestination.from_message(message)
  end

  defp get_audio_for_line(
         {_, %Message.Alert.NoServiceUseShuttle{} = message},
         _line,
         _multi_source?
       ) do
    Audio.NoServiceToDestination.from_message(message)
  end

  defp get_audio_for_line({_, %Message.Empty{}}, _line, _multi_source?) do
    []
  end

  defp get_audio_for_line(content, _line, _multi_source?) do
    Logger.error("message_to_audio_error Utilities.Audio unknown_line #{inspect(content)}")
    []
  end
end
