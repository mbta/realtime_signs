defmodule Signs.Utilities.Audio do
  @moduledoc """
  Takes a sign and returns the list of audio structs to be sent to ARINC.
  """

  alias Content.Audio
  alias Signs.Utilities.SourceConfig
  require Logger

  @announced_history_length 5

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
                      prediction.trip_id not in sign.announced_approachings)) ->
              {Audio.TrainIsBoarding.new(prediction, message.special_sign),
               update_in(sign.announced_boardings, &cache_value(&1, prediction.trip_id))}

            # Announce approaching if configured to
            PaEss.Utilities.prediction_approaching?(prediction, message.terminal?) &&
              prediction.trip_id not in sign.announced_approachings &&
                announce_arriving?(sign, prediction) ->
              crowding = Signs.Utilities.Crowding.crowding_description(prediction, sign)
              new_cars? = PaEss.Utilities.prediction_new_cars?(prediction)

              {Audio.Approaching.new(prediction, crowding, new_cars?),
               sign
               |> update_in(
                 [Access.key!(:announced_approachings)],
                 &cache_value(&1, prediction.trip_id)
               )}

            # Announce stopped trains
            PaEss.Utilities.prediction_stopped?(prediction, message.terminal?) && index == 0 &&
                prediction_stopped_key(prediction) not in sign.announced_stalls ->
              {Audio.Predictions.new(
                 prediction,
                 message.special_sign,
                 message.terminal?,
                 length(messages) > 1,
                 :next,
                 true
               ),
               update_in(
                 sign.announced_stalls,
                 &cache_value(&1, prediction_stopped_key(prediction))
               )}

            # If we didn't have any predictions for a particular route/direction last update, but
            # now we do, announce the next prediction.
            is_integer(minutes) && index == 0 && sign.prev_prediction_keys &&
                prediction_key(prediction) not in sign.prev_prediction_keys ->
              {Audio.Predictions.new(
                 prediction,
                 message.special_sign,
                 message.terminal?,
                 length(messages) > 1,
                 :next,
                 true
               ), sign}

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
      Enum.map(new_audios, fn
        %Audio.Approaching{} = audio -> %{audio | crowding_description: nil}
        audio -> audio
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
      %Audio.Approaching{
        trip_id: trip_id,
        crowding_description: crowding_description,
        route_id: "Orange"
      } ->
        Logger.info(
          "crowding_log: announcement_type=approaching trip_id=#{trip_id} sign_id=#{sign_id} crowding_description=#{inspect(crowding_description)}"
        )

      _ ->
        nil
    end)
  end

  @spec send_audio([Signs.Realtime.t() | Signs.Bus.t()], [Content.Audio.t()]) :: :ok
  def send_audio(signs, audios) do
    RealtimeSigns.sign_updater().play_message(
      signs,
      Enum.map(audios, &Content.Audio.to_params(&1)),
      Enum.map(audios, &Content.Audio.to_tts(&1)),
      case audios do
        [%PaMessages.PaMessage{priority: priority}] -> priority
        _ -> 2
      end,
      Enum.map(audios, &Content.Audio.to_logs(&1))
    )
  end

  def play_pa_messages(sign, now, opts \\ []) do
    RealtimeSigns.pa_message_engine().for_sign(sign.id)
    |> Enum.reduce(sign, fn pa_message, sign ->
      update_in(sign, [Access.key!(:pa_message_schedules), pa_message.id], fn next ->
        new_next = DateTime.add(now, pa_message.interval_in_ms, :millisecond)

        cond do
          # If the interval is changed to be shorter, bump the schedule up if needed
          next && DateTime.before?(now, next) ->
            earlier_datetime(next, new_next)

          # Skip playback
          (opts[:overnight?] && pa_message.priority > 1) ||
              (opts[:upcoming_announcement?] && pa_message.priority > 2) ->
            new_next

          # Defer playback
          opts[:upcoming_announcement?] && pa_message.priority > 1 ->
            DateTime.add(now, 30)

          true ->
            send_audio([sign], [pa_message])
            new_next
        end
      end)
    end)
  end

  defp earlier_datetime(a, b), do: if(DateTime.compare(a, b) == :gt, do: b, else: a)
end
