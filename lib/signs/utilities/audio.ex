defmodule Signs.Utilities.Audio do
  @moduledoc """
  Takes a sign and returns the list of audio structs to be sent to ARINC.
  """

  alias Content.Audio
  alias Signs.Utilities.SourceConfig
  require Logger

  @announced_history_length 5
  @heavy_rail_routes ["Red", "Orange", "Blue"]

  @spec get_announcements(Signs.Realtime.t(), [Message.t()]) ::
          {[Content.Audio.t()], Signs.Realtime.t()}
  def get_announcements(sign, messages) do
    {[], sign}
    |> get_custom_announcements(messages)
    |> get_alert_announcements(messages)
    |> get_prediction_announcements(messages)
  end

  defp get_custom_announcements({audios, sign}, messages) do
    case Enum.find(messages, &match?(%Message.Custom{}, &1)) do
      %Message.Custom{} = message ->
        [audio] = Message.to_audio(message, length(messages) > 1)

        if sign.announced_custom_text != audio.message do
          {audios ++ [audio], %{sign | announced_custom_text: audio.message}}
        else
          {audios, sign}
        end

      nil ->
        {audios, %{sign | announced_custom_text: nil}}
    end
  end

  defp get_alert_announcements({audios, sign}, messages) do
    case Enum.find(messages, &match?(%Message.Alert{}, &1)) do
      %Message.Alert{} = message ->
        if !sign.announced_alert do
          {audios ++ Message.to_audio(message, length(messages) > 1),
           %{sign | announced_alert: true}}
        else
          {audios, sign}
        end

      nil ->
        {audios, %{sign | announced_alert: false}}
    end
  end

  defp get_prediction_announcements({audios, sign}, messages) do
    {new_audios, sign} =
      Stream.filter(messages, &match?(%Message.Predictions{}, &1))
      |> Enum.flat_map_reduce(sign, fn message, sign ->
        Stream.with_index(message.predictions)
        |> Enum.flat_map_reduce(sign, fn {prediction, index}, sign ->
          {minutes, _} = PaEss.Utilities.prediction_minutes(prediction, message.terminal?)

          cond do
            # Announce boarding if configured to. Also, if we normally announce arrivals, but the
            # prediction went straight to boarding, announce boarding instead.
            minutes == :boarding &&
              prediction.trip_id not in sign.announced_boardings &&
                (announce_boarding?(sign, prediction) ||
                   (announce_arriving?(sign, prediction) &&
                      prediction.trip_id not in sign.announced_arrivals)) ->
              {Audio.TrainIsBoarding.new(prediction, message.special_sign),
               update_in(sign.announced_boardings, &cache_value(&1, prediction.trip_id))}

            # Announce arriving if configured to
            minutes == :arriving &&
              prediction.trip_id not in sign.announced_arrivals &&
                announce_arriving?(sign, prediction) ->
              crowding =
                if prediction.trip_id not in sign.announced_approachings_with_crowding do
                  Signs.Utilities.Crowding.crowding_description(prediction, sign)
                end

              {Audio.TrainIsArriving.new(prediction, crowding),
               update_in(sign.announced_arrivals, &cache_value(&1, prediction.trip_id))}

            # Announce approaching if configured to
            PaEss.Utilities.prediction_approaching?(prediction, message.terminal?) &&
              prediction.trip_id not in sign.announced_approachings &&
              announce_arriving?(sign, prediction) &&
                prediction.route_id in @heavy_rail_routes ->
              crowding = Signs.Utilities.Crowding.crowding_description(prediction, sign)
              new_cars? = PaEss.Utilities.prediction_new_cars?(prediction)

              {Audio.Approaching.new(prediction, crowding, new_cars?),
               sign
               |> update_in(
                 [Access.key!(:announced_approachings)],
                 &cache_value(&1, prediction.trip_id)
               )
               |> update_in(
                 [Access.key!(:announced_approachings_with_crowding)],
                 &if(!!crowding, do: cache_value(&1, prediction.trip_id), else: &1)
               )}

            # Announce stopped trains
            PaEss.Utilities.prediction_stopped?(prediction, message.terminal?) && index == 0 &&
                prediction_stopped_key(prediction) not in sign.announced_stalls ->
              {Audio.Predictions.new(prediction, message.special_sign, message.terminal?, :next),
               update_in(
                 sign.announced_stalls,
                 &cache_value(&1, prediction_stopped_key(prediction))
               )}

            # If we didn't have any predictions for a particular route/direction last update, but
            # now we do, announce the next prediction.
            is_integer(minutes) && index == 0 && sign.prev_prediction_keys &&
                prediction_key(prediction) not in sign.prev_prediction_keys ->
              {Audio.Predictions.new(prediction, message.special_sign, message.terminal?, :next),
               sign}

            true ->
              {[], sign}
          end
        end)
      end)

    log_crowding(new_audios, sign.id)

    sign = %{
      sign
      | prev_prediction_keys:
          for %Message.Predictions{} = message <- messages,
              prediction <- message.predictions,
              uniq: true do
            prediction_key(prediction)
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

  defp prediction_key(prediction) do
    {prediction.route_id, prediction.direction_id}
  end

  defp prediction_stopped_key(prediction) do
    {prediction.trip_id, PaEss.Utilities.prediction_stops_away(prediction)}
  end

  defp cache_value(list, value), do: [value | list] |> Enum.take(@announced_history_length)

  defp announce_arriving?(
         %Signs.Realtime{source_config: source_config},
         %Predictions.Prediction{stop_id: stop_id, direction_id: direction_id}
       ) do
    case SourceConfig.get_source_by_stop_and_direction(source_config, stop_id, direction_id) do
      nil -> false
      source -> source.announce_arriving?
    end
  end

  defp announce_boarding?(
         %Signs.Realtime{source_config: source_config},
         %Predictions.Prediction{stop_id: stop_id, direction_id: direction_id}
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
