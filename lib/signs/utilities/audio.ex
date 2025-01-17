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

  @spec from_sign(Signs.Realtime.t(), Content.Message.t(), Content.Message.t()) ::
          {[Content.Audio.t()], Signs.Realtime.t()}
  def from_sign(sign, top_content, bottom_content) do
    {Enum.flat_map(decode_sign(sign, top_content, bottom_content), &get_passive_readout/1), sign}
  end

  @spec get_passive_readout(
          {atom(), Content.Message.t(), Content.Message.t() | nil}
          | {atom(), [Content.Message.t()]}
        ) :: [Content.Audio.t()]
  defp get_passive_readout({:custom, top, bottom}) do
    Audio.Custom.from_messages(top, bottom)
  end

  defp get_passive_readout({:headway, top, bottom}) do
    Audio.VehiclesToDestination.from_messages(top, bottom)
  end

  defp get_passive_readout({:scheduled_train, top, bottom}) do
    Audio.FirstTrainScheduled.from_messages(top, bottom)
  end

  defp get_passive_readout({:alert, top, bottom}) do
    Audio.NoService.from_messages(top, bottom)
  end

  defp get_passive_readout({:predictions, predictions}) do
    case predictions do
      [
        %Message.StoppedTrain{destination: same} = top,
        %Message.StoppedTrain{destination: same}
      ] ->
        Audio.Predictions.from_message(top, :next)

      [
        %Message.StoppedTrain{destination: same} = top,
        %Message.Predictions{destination: same} = bottom
      ] ->
        Audio.Predictions.from_message(top, :next) ++
          Audio.Predictions.from_message(bottom, :following)

      [
        %Message.Predictions{destination: same} = top,
        %Message.StoppedTrain{destination: same}
      ] ->
        get_prediction_readout(top)

      [
        %Message.Predictions{destination: same} = top,
        %Message.Predictions{destination: same} = bottom
      ] ->
        get_prediction_readout(top) ++
          Audio.Predictions.from_message(bottom, :following)

      _ ->
        Enum.flat_map(predictions, &get_prediction_readout/1)
    end
  end

  defp get_passive_readout({:service_ended, top, _}) do
    Audio.ServiceEnded.from_message(top)
  end

  defp get_prediction_readout(%Message.Predictions{minutes: minutes} = prediction) do
    case minutes do
      :boarding ->
        Audio.TrainIsBoarding.from_message(prediction)

      :arriving ->
        Audio.TrainIsArriving.from_message(prediction, nil)

      minutes when is_integer(minutes) ->
        Audio.Predictions.from_message(prediction, :next)

      _ ->
        []
    end
  end

  defp get_prediction_readout(%Message.StoppedTrain{} = prediction) do
    Audio.Predictions.from_message(prediction, :next)
  end

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
        new_audios = Content.Audio.NoService.from_messages(top, bottom)

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
              message.prediction.trip_id not in sign.announced_boardings &&
                (announce_boarding?(sign, message) ||
                   (announce_arriving?(sign, message) &&
                      message.prediction.trip_id not in sign.announced_arrivals)) ->
              {Audio.TrainIsBoarding.from_message(message),
               update_in(sign.announced_boardings, &cache_value(&1, message.prediction.trip_id))}

            # Announce arriving if configured to
            match?(%Message.Predictions{minutes: :arriving}, message) &&
              message.prediction.trip_id not in sign.announced_arrivals &&
                announce_arriving?(sign, message) ->
              crowding =
                if message.prediction.trip_id not in sign.announced_approachings_with_crowding do
                  Signs.Utilities.Crowding.crowding_description(message.prediction, sign)
                end

              {Audio.TrainIsArriving.from_message(message, crowding),
               update_in(sign.announced_arrivals, &cache_value(&1, message.prediction.trip_id))}

            # Announce approaching if configured to
            match?(%Message.Predictions{}, message) &&
              PaEss.Utilities.prediction_approaching?(message.prediction, message.terminal?) &&
              message.prediction.trip_id not in sign.announced_approachings &&
              announce_arriving?(sign, message) &&
                message.prediction.route_id in @heavy_rail_routes ->
              crowding = Signs.Utilities.Crowding.crowding_description(message.prediction, sign)
              new_cars? = PaEss.Utilities.prediction_new_cars?(message.prediction)

              {Audio.Approaching.from_message(message, crowding, new_cars?),
               sign
               |> update_in(
                 [Access.key!(:announced_approachings)],
                 &cache_value(&1, message.prediction.trip_id)
               )
               |> update_in(
                 [Access.key!(:announced_approachings_with_crowding)],
                 &if(!!crowding, do: cache_value(&1, message.prediction.trip_id), else: &1)
               )}

            # Announce stopped trains
            match?(%Message.StoppedTrain{}, message) && index == 0 &&
                {message.prediction.trip_id, message.stops_away} not in sign.announced_stalls ->
              {Audio.Predictions.from_message(message, :next),
               update_in(
                 sign.announced_stalls,
                 &cache_value(&1, {message.prediction.trip_id, message.stops_away})
               )}

            # If we didn't have any predictions for a particular route/direction last update, but
            # now we do, announce the next prediction.
            match?(%Message.Predictions{}, message) && is_integer(message.minutes) && index == 0 &&
              sign.prev_prediction_keys &&
                {message.prediction.route_id, message.prediction.direction_id} not in sign.prev_prediction_keys ->
              {Audio.Predictions.from_message(message, :next), sign}

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
            {message.prediction.route_id, message.prediction.direction_id}
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
          | {:headway, Content.Message.t(), Content.Message.t() | nil}
          | {:scheduled_train, Content.Message.t(), Content.Message.t() | nil}
          | {:service_ended, Content.Message.t(), Content.Message.t() | nil}
        ]
  defp decode_sign(sign, top_content, bottom_content) do
    case {sign, top_content, bottom_content} do
      {_, top, bottom}
      when top.__struct__ == Message.Custom or bottom.__struct__ == Message.Custom ->
        [{:custom, top, bottom}]

      {_, %Message.Headways.Top{} = top, %Message.Headways.Bottom{} = bottom} ->
        [{:headway, top, bottom}]

      {_, %Message.Alert.NoService{} = top, bottom} ->
        [{:alert, top, bottom}]

      {_, %Message.GenericPaging{} = top, %Message.GenericPaging{} = bottom} ->
        Enum.zip(top.messages, bottom.messages) |> Enum.flat_map(&decode_lines/1)

      {_, %Message.LastTrip.PlatformClosed{} = top, bottom} ->
        [{:service_ended, top, bottom}]

      {_, %Message.LastTrip.StationClosed{} = top, bottom} ->
        [{:service_ended, top, bottom}]

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

      {%Message.Predictions{}, %Message.PlatformPredictionBottom{}} ->
        [{:predictions, [%{top | special_sign: :jfk_mezzanine}]}]

      {top, _} when top.__struct__ in [Message.Predictions, Message.StoppedTrain] ->
        [{:predictions, [top]}]

      {%Message.Headways.Top{}, %Message.Headways.Bottom{}} ->
        [{:headway, top, bottom}]

      {%Message.Alert.NoService{}, _} ->
        [{:alert, top, bottom}]

      {%Message.EarlyAm.DestinationTrain{}, %Message.EarlyAm.ScheduledTime{}} ->
        [{:scheduled_train, top, bottom}]

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
      %Message.Headways.Paging{} -> [{:headway, line, nil}]
      %Message.EarlyAm.DestinationScheduledTime{} -> [{:scheduled_train, line, nil}]
      %Message.LastTrip.NoService{} -> [{:service_ended, line, nil}]
      _ -> []
    end
  end

  defp announce_arriving?(
         %Signs.Realtime{source_config: source_config},
         %Message.Predictions{prediction: %{stop_id: stop_id, direction_id: direction_id}}
       ) do
    case SourceConfig.get_source_by_stop_and_direction(source_config, stop_id, direction_id) do
      nil -> false
      source -> source.announce_arriving?
    end
  end

  defp announce_boarding?(
         %Signs.Realtime{source_config: source_config},
         %Message.Predictions{prediction: %{stop_id: stop_id, direction_id: direction_id}}
       ) do
    case SourceConfig.get_source_by_stop_and_direction(source_config, stop_id, direction_id) do
      nil -> false
      source -> source.announce_boarding?
    end
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

  @spec send_audio(Signs.Realtime.t() | Signs.Bus.t(), [Content.Audio.t()]) :: :ok
  def send_audio(sign, audios) do
    RealtimeSigns.sign_updater().play_message(
      sign,
      Enum.map(audios, &Content.Audio.to_params(&1)),
      Enum.map(audios, &Content.Audio.to_tts(&1)),
      Enum.map(audios, fn audio ->
        [message_type: Module.split(audio.__struct__) |> List.last()] ++
          Content.Audio.to_logs(audio)
      end)
    )
  end

  @spec handle_pa_message_play(PaMessages.PaMessage.t(), Signs.Realtime.t() | Signs.Bus.t()) ::
          {Signs.Realtime.t() | Signs.Bus.t(), boolean()}
  def handle_pa_message_play(pa_message, sign) do
    last_sent = sign.pa_message_plays[pa_message.id]
    now = DateTime.utc_now()

    if !last_sent || DateTime.diff(now, last_sent, :millisecond) >= pa_message.interval_in_ms do
      Logger.info("pa_message: action=send id=#{pa_message.id} destination=#{sign.id}")
      {update_in(sign.pa_message_plays, &Map.put(&1, pa_message.id, now)), true}
    else
      Logger.warn("pa_message: action=skipped id=#{pa_message.id} destination=#{sign.id}")
      {sign, false}
    end
  end
end
