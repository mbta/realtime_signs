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

  @spec get_announcements(Signs.Realtime.t(), Content.Message.t(), Content.Message.t()) ::
          {[Content.Audio.t()], Signs.Realtime.t()}
  def get_announcements(sign, top_content, bottom_content) do
    items = decode_sign(sign, top_content, bottom_content)

    {[], sign}
    |> get_custom_announcements(items)
    |> get_alert_announcements(items)
    |> get_prediction_announcements(items)
  end

  defp get_custom_announcements({audios, sign}, items) do
    case Enum.find(items, &match?({:custom, _, _}, &1)) do
      {:custom, top, bottom} ->
        [audio] = Audio.Custom.from_messages(top, bottom)

        if sign.announced_custom_text != audio.message do
          {audios ++ [audio], %{sign | announced_custom_text: audio.message}}
        else
          {audios, sign}
        end

      nil ->
        {audios, %{sign | announced_custom_text: nil}}
    end
  end

  defp get_alert_announcements({audios, sign}, items) do
    case Enum.find(items, &match?({:alert, _, _}, &1)) do
      {:alert, top, bottom} ->
        new_audios =
          case top do
            %Message.Alert.NoService{} ->
              Audio.Closure.from_messages(top, bottom)

            %Message.Alert.DestinationNoService{} ->
              Audio.NoServiceToDestination.from_message(top)

            %Message.Alert.NoServiceUseShuttle{} ->
              Audio.NoServiceToDestination.from_message(top)
          end

        if !sign.announced_alert do
          {audios ++ new_audios, %{sign | announced_alert: true}}
        else
          {audios, sign}
        end

      nil ->
        {audios, %{sign | announced_alert: false}}
    end
  end

  defp get_prediction_announcements({audios, sign}, items) do
    {new_audios, sign} =
      Stream.filter(items, &match?({:predictions, _}, &1))
      |> Enum.flat_map_reduce(sign, fn {:predictions, messages}, sign ->
        Stream.with_index(messages)
        |> Enum.flat_map_reduce(sign, fn {message, index}, sign ->
          cond do
            # Announce boarding if configured to. Also, if we normally announce arrivals, but the
            # prediction went straight to boarding, announce boarding instead.
            match?(%Message.Predictions{minutes: :boarding}, message) &&
              message.trip_id not in sign.announced_boardings &&
                (announce_boarding?(sign, message) ||
                   (announce_arriving?(sign, message) &&
                      message.trip_id not in sign.announced_arrivals)) ->
              {Audio.TrainIsBoarding.from_message(message),
               update_in(sign.announced_boardings, &cache_value(&1, message.trip_id))}

            # Announce arriving if configured to
            match?(%Message.Predictions{minutes: :arriving}, message) &&
              message.trip_id not in sign.announced_arrivals &&
                announce_arriving?(sign, message) ->
              include_crowding? =
                message.crowding_data_confidence == :high &&
                  message.trip_id not in sign.announced_approachings_with_crowding

              {Audio.TrainIsArriving.from_message(message, include_crowding?),
               update_in(sign.announced_arrivals, &cache_value(&1, message.trip_id))}

            # Announce approaching if configured to
            match?(%Message.Predictions{minutes: :approaching}, message) &&
              message.trip_id not in sign.announced_approachings &&
              announce_arriving?(sign, message) &&
                message.route_id in @heavy_rail_routes ->
              include_crowding? = message.crowding_data_confidence == :high

              {Audio.Approaching.from_message(message, include_crowding?),
               sign
               |> update_in(
                 [Access.key!(:announced_approachings)],
                 &cache_value(&1, message.trip_id)
               )
               |> update_in(
                 [Access.key!(:announced_approachings_with_crowding)],
                 &if(include_crowding?, do: cache_value(&1, message.trip_id), else: &1)
               )}

            # Announce stopped trains
            match?(%Message.StoppedTrain{}, message) && index == 0 &&
                {message.trip_id, message.stops_away} not in sign.announced_stalls ->
              {Audio.StoppedTrain.from_message(message),
               update_in(
                 sign.announced_stalls,
                 &cache_value(&1, {message.trip_id, message.stops_away})
               )}

            # If we didn't have any predictions for a particular route/direction last update, but
            # now we do, announce the next prediction.
            match?(%Message.Predictions{}, message) && is_integer(message.minutes) && index == 0 &&
              sign.prev_prediction_keys &&
                {message.route_id, message.direction_id} not in sign.prev_prediction_keys ->
              {Audio.NextTrainCountdown.from_message(message), sign}

            true ->
              {[], sign}
          end
        end)
      end)

    log_crowding(new_audios, sign.id)

    sign = %{
      sign
      | prev_prediction_keys:
          for {:predictions, list} <- items, message <- list, uniq: true do
            {message.route_id, message.direction_id}
          end
    }

    # Disable crowding messages for now
    new_audios =
      Enum.map(new_audios, fn %{__struct__: audio_type} = audio ->
        if audio_type in [Audio.Approaching, Audio.TrainIsArriving] and sign.id not in [] do
          %{audio | crowding_description: nil}
        else
          audio
        end
      end)

    {audios ++ new_audios, sign}
  end

  defp cache_value(list, value), do: [value | list] |> Enum.take(@announced_history_length)

  # Reconstructs higher level information about what's being shown on the sign, in a form that's
  # suitable for computing audio messages. Eventually the goal is to produce this information
  # earlier in the pipeline, rather than deriving it here.
  @spec decode_sign(Signs.Realtime.t(), Content.Message.t(), Content.Message.t()) :: [
          {:custom, Content.Message.t(), Content.Message.t()}
          | {:alert, Content.Message.t(), Content.Message.t() | nil}
          | {:predictions, [Content.Message.t()]}
        ]
  defp decode_sign(sign, top_content, bottom_content) do
    case {sign, top_content, bottom_content} do
      {_, top, bottom}
      when top.__struct__ == Message.Custom or bottom.__struct__ == Message.Custom ->
        [{:custom, top, bottom}]

      {_, %Message.Alert.NoService{} = top, bottom} ->
        [{:alert, top, bottom}]

      {_, %Message.GenericPaging{} = top, %Message.GenericPaging{} = bottom} ->
        Enum.zip(top.messages, bottom.messages) |> Enum.map(&decode_lines/1)

      # Mezzanine signs get separate treatment for each half, e.g. they will return two
      # separate prediction lists with one prediction each.
      {%Signs.Realtime{source_config: {_, _}}, top, bottom} ->
        decode_line(top) ++ decode_line(bottom)

      {_, top, bottom} ->
        decode_lines({top, bottom})
    end
  end

  defp decode_lines({top, bottom}) do
    case {top, bottom} do
      {top, bottom}
      when top.__struct__ in [Message.Predictions, Message.StoppedTrain] and
             bottom.__struct__ in [Message.Predictions, Message.StoppedTrain] ->
        [{:predictions, [top, bottom]}]

      {top, _} when top.__struct__ in [Message.Predictions, Message.StoppedTrain] ->
        [{:predictions, [top]}]

      _ ->
        []
    end
  end

  defp decode_line(line) do
    case line do
      %Message.Predictions{} -> [{:predictions, [line]}]
      %Message.StoppedTrain{} -> [{:predictions, [line]}]
      %Message.Alert.NoServiceUseShuttle{} -> [{:alert, line, nil}]
      %Message.Alert.DestinationNoService{} -> [{:alert, line, nil}]
      _ -> []
    end
  end

  defp announce_arriving?(
         %Signs.Realtime{source_config: source_config},
         %Message.Predictions{stop_id: stop_id, direction_id: direction_id}
       ) do
    case SourceConfig.get_source_by_stop_and_direction(source_config, stop_id, direction_id) do
      nil -> false
      source -> source.announce_arriving?
    end
  end

  defp announce_boarding?(
         %Signs.Realtime{source_config: source_config},
         %Message.Predictions{stop_id: stop_id, direction_id: direction_id}
       ) do
    case SourceConfig.get_source_by_stop_and_direction(source_config, stop_id, direction_id) do
      nil -> false
      source -> source.announce_boarding?
    end
  end

  @spec from_sign(Signs.Realtime.t(), Content.Message.t(), Content.Message.t()) ::
          {[Content.Audio.t()], Signs.Realtime.t()}
  def from_sign(sign, top_content, bottom_content) do
    multi_source? = SourceConfig.multi_source?(sign.source_config)
    {get_audio(top_content, bottom_content, multi_source?), sign}
  end

  defp log_crowding(new_audios, sign_id) do
    Enum.each(new_audios, fn
      %{
        trip_id: trip_id,
        crowding_description: crowding_description,
        route_id: "Orange",
        __struct__: audio_type
      }
      when audio_type in [Audio.Approaching, Audio.TrainIsArriving] ->
        announcement_type =
          case audio_type do
            Audio.Approaching -> "approaching"
            Audio.TrainIsArriving -> "arrival"
          end

        Logger.info(
          "crowding_log: announcement_type=#{announcement_type} trip_id=#{trip_id} sign_id=#{sign_id} crowding_description=#{inspect(crowding_description)}"
        )

      _ ->
        nil
    end)
  end

  @spec get_audio(Signs.Realtime.line_content(), Signs.Realtime.line_content(), boolean()) ::
          [Content.Audio.t()]
  defp get_audio(
         %Message.Alert.NoService{} = top,
         bottom,
         _multi_source?
       ) do
    Audio.Closure.from_messages(top, bottom)
  end

  defp get_audio(
         %Message.Custom{} = top,
         bottom,
         _multi_source?
       ) do
    Audio.Custom.from_messages(top, bottom)
  end

  defp get_audio(
         top,
         %Message.Custom{} = bottom,
         _multi_source?
       ) do
    Audio.Custom.from_messages(top, bottom)
  end

  defp get_audio(
         %Message.Headways.Top{} = top,
         bottom,
         _multi_source?
       ) do
    Audio.VehiclesToDestination.from_headway_message(top, bottom)
  end

  defp get_audio(
         %Message.Predictions{minutes: :arriving, route_id: route_id} = top_content,
         _bottom_content,
         multi_source?
       )
       when route_id in @heavy_rail_routes do
    Audio.Predictions.from_sign_content(top_content, :top, multi_source?)
  end

  defp get_audio(
         _top_content,
         %Message.Predictions{minutes: :arriving, route_id: route_id} = bottom_content,
         multi_source?
       )
       when multi_source? and route_id in @heavy_rail_routes do
    Audio.Predictions.from_sign_content(bottom_content, :bottom, multi_source?)
  end

  defp get_audio(
         %Message.Predictions{destination: same} = content_top,
         %Message.Predictions{destination: same} = content_bottom,
         multi_source?
       ) do
    Audio.Predictions.from_sign_content(content_top, :top, multi_source?) ++
      Audio.FollowingTrain.from_predictions_message(content_bottom)
  end

  defp get_audio(
         %Message.StoppedTrain{destination: same} = top,
         %Message.StoppedTrain{destination: same},
         _multi_source?
       ) do
    Audio.StoppedTrain.from_message(top)
  end

  defp get_audio(
         %Message.StoppedTrain{destination: same} = top,
         %Message.Predictions{destination: same},
         _multi_source?
       ) do
    Audio.StoppedTrain.from_message(top)
  end

  defp get_audio(
         %Message.Predictions{destination: same} = top_content,
         %Message.StoppedTrain{destination: same},
         multi_source?
       ) do
    Audio.Predictions.from_sign_content(top_content, :top, multi_source?)
  end

  defp get_audio(
         %Message.GenericPaging{messages: top_messages},
         %Message.GenericPaging{messages: bottom_messages},
         _multi_source?
       ) do
    if length(top_messages) != length(bottom_messages) do
      Logger.error(
        "message_to_audio_warning Utilities.Audio generic_paging_mismatch some audios will be dropped: #{inspect(top_messages)} #{inspect(bottom_messages)}"
      )
    end

    Enum.zip(top_messages, bottom_messages)
    |> Enum.flat_map(fn {top, bottom} ->
      get_audio(top, bottom, false)
    end)
  end

  defp get_audio(
         %Message.EarlyAm.DestinationTrain{} = top,
         %Message.EarlyAm.ScheduledTime{} = bottom,
         _multi_source?
       ) do
    Audio.FirstTrainScheduled.from_messages(top, bottom)
  end

  # Get audio for JFK/UMass special case two-line platform prediction
  defp get_audio(
         %Message.Predictions{station_code: "RJFK"} = top_content,
         %Message.PlatformPredictionBottom{},
         multi_source?
       ) do
    # When the JFK/UMass Mezzanine sign is paging between two full pages where
    # one page is a prediction with platform information on the second line,
    # we have to override the zone field in Signs.Utilities.Messages.get_messages()
    # to avoid triggering the usual paging platform prediction. The audio readout
    # should be read normally though with platform info, so we add the zone back in here.
    #
    # Additionally, the second parameter here for from_sign_content/3 is arbitrary in this case.
    Audio.Predictions.from_sign_content(%{top_content | zone: "m"}, :bottom, multi_source?)
  end

  defp get_audio(top, bottom, multi_source?) do
    get_audio_for_line(top, :top, multi_source?) ++
      get_audio_for_line(bottom, :bottom, multi_source?)
  end

  @spec get_audio_for_line(Signs.Realtime.line_content(), Content.line_location(), boolean()) ::
          [Content.Audio.t()]
  defp get_audio_for_line(%Message.StoppedTrain{} = message, _line, _multi_source?) do
    Audio.StoppedTrain.from_message(message)
  end

  defp get_audio_for_line(%Message.Predictions{} = content, line, multi_source?) do
    Audio.Predictions.from_sign_content(content, line, multi_source?)
  end

  defp get_audio_for_line(%Message.Headways.Paging{} = message, _line, _multi_source?) do
    Audio.VehiclesToDestination.from_paging_headway_message(message)
  end

  defp get_audio_for_line(
         %Message.Alert.DestinationNoService{} = message,
         _line,
         _multi_source?
       ) do
    Audio.NoServiceToDestination.from_message(message)
  end

  defp get_audio_for_line(
         %Message.Alert.NoServiceUseShuttle{} = message,
         _line,
         _multi_source?
       ) do
    Audio.NoServiceToDestination.from_message(message)
  end

  defp get_audio_for_line(
         %Message.EarlyAm.DestinationScheduledTime{} = message,
         _line,
         _multi_source?
       ) do
    Audio.FirstTrainScheduled.from_messages(message)
  end

  defp get_audio_for_line(%Message.Empty{}, _line, _multi_source?) do
    []
  end

  defp get_audio_for_line(content, _line, _multi_source?) do
    Logger.error("message_to_audio_error Utilities.Audio unknown_line #{inspect(content)}")
    []
  end

  def audio_log_details(audio) do
    [
      message_type: to_string(audio.__struct__) |> String.split(".") |> List.last(),
      message_details: Map.from_struct(audio) |> inspect()
    ]
  end
end
