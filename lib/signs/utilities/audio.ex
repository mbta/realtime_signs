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
  # If minutes is an integer, we don't interrupt
  def should_interrupting_read?(%Content.Message.Predictions{minutes: x}, _sign, _line)
      when is_integer(x) do
    false
  end

  # If train is approaching and it's not a heavy rail route, we don't interrupt
  def should_interrupting_read?(
        %Content.Message.Predictions{minutes: :approaching, route_id: route_id},
        _sign,
        _line
      )
      when route_id not in @heavy_rail_routes do
    false
  end

  # If train is arriving or approaching and it's being shown on the bottom line, check if it is multi-source and if we announce arriving
  def should_interrupting_read?(
        %Content.Message.Predictions{minutes: arriving_or_approaching} = prediction,
        %Signs.Realtime{source_config: config},
        :bottom
      )
      when arriving_or_approaching in [:arriving, :approaching] do
    SourceConfig.multi_source?(config) and
      announce_arriving?(config, prediction)
  end

  # If train is arriving or approaching, check if we announce arriving for this stop
  def should_interrupting_read?(
        %Content.Message.Predictions{minutes: arriving_or_approaching} = prediction,
        %Signs.Realtime{source_config: config},
        _line
      )
      when arriving_or_approaching in [:arriving, :approaching] do
    announce_arriving?(config, prediction)
  end

  # If train is boarding, check if we announce boarding for this stop
  # Special case: if arriving announcement was skipped, then interrupt and announce boarding even if we don't normally announce boarding
  def should_interrupting_read?(
        %Content.Message.Predictions{minutes: :boarding, trip_id: trip_id} = prediction,
        %Signs.Realtime{
          id: sign_id,
          announced_arrivals: announced_arrivals,
          source_config: config
        },
        _line
      ) do
    case announce_boarding?(config, prediction) do
      true ->
        true

      false ->
        if trip_id not in announced_arrivals do
          Logger.info(
            "announced_brd_when_arr_skipped trip_id=#{inspect(trip_id)} sign_id=#{inspect(sign_id)}"
          )

          true
        else
          false
        end
    end
  end

  def should_interrupting_read?(%Content.Message.Empty{}, _sign, _line) do
    false
  end

  def should_interrupting_read?(%Content.Message.StoppedTrain{}, _sign, :bottom) do
    false
  end

  def should_interrupting_read?(%Content.Message.Headways.Bottom{}, _sign, _line) do
    false
  end

  def should_interrupting_read?(%Content.Message.Headways.Paging{}, _sign, _line) do
    false
  end

  def should_interrupting_read?(%Content.Message.Alert.NoServiceUseShuttle{}, _sign, _line) do
    false
  end

  def should_interrupting_read?(%Content.Message.Alert.DestinationNoService{}, _sign, _line) do
    false
  end

  def should_interrupting_read?(_content, _sign, _line) do
    true
  end

  defp announce_arriving?(source_config, prediction) do
    source_config
    |> SourceConfig.get_source_by_stop_and_direction(prediction.stop_id, prediction.direction_id)
    |> case do
      nil ->
        false

      source ->
        source.announce_arriving?
    end
  end

  defp announce_boarding?(source_config, prediction) do
    source_config
    |> SourceConfig.get_source_by_stop_and_direction(prediction.stop_id, prediction.direction_id)
    |> case do
      nil ->
        false

      source ->
        source.announce_boarding?
    end
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
            %Audio.TrainIsArriving{trip_id: trip_id, crowding_description: crowding_description}
            when not is_nil(trip_id) ->
              cond do
                # If we've already announced the arrival, don't announce it
                audio.trip_id in sign.announced_arrivals ->
                  {new_audios, new_approaching_trips, new_arriving_trips}

                # If the arrival has high-confidence crowding info but we've already announced crowding with the approaching message, announce it without crowding
                crowding_description && audio.trip_id in sign.announced_approachings_with_crowding ->
                  {new_audios ++ [%{audio | crowding_description: nil}], new_approaching_trips,
                   [audio.trip_id | new_arriving_trips]}

                # else, announce normally
                true ->
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

    new_announced_approaching_with_crowding =
      Enum.filter(new_audios, fn
        %Audio.Approaching{trip_id: trip_id, crowding_description: crowding_description} ->
          not is_nil(trip_id) and not is_nil(crowding_description)

        _ ->
          false
      end)
      |> Enum.map(& &1.trip_id)

    sign = %{
      sign
      | announced_approachings: Enum.take(new_approaching_trips, @announced_history_length),
        announced_approachings_with_crowding:
          Enum.take(
            new_announced_approaching_with_crowding ++ sign.announced_approachings_with_crowding,
            @announced_history_length
          ),
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
end
