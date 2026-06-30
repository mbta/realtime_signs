defmodule Signs.Utilities.Messages do
  @moduledoc """
  Helper functions for deciding which message a sign should
  be displaying
  """

  @early_am_start ~T[04:00:00]
  @early_am_buffer -40
  @overnight_buffer 30

  alias Signs.Utilities.SignContext
  alias SignContext.ConfigContext

  @spec get_messages(Signs.Realtime.t(), SignContext.t()) :: [Message.t()]
  def get_messages(sign, %SignContext{sign_config: sign_config} = sign_context) do
    sign_in_overnight_period = in_overnight_period?(sign_context)

    cond do
      match?({:static_text, {_, _, _}}, sign_config) ->
        if sign_in_overnight_period do
          [%Message.Empty{}]
        else
          {:static_text, {line1, line2, audio_text}} = sign_config
          [%Message.Custom{top: line1, bottom: line2, audio_text: audio_text}]
        end

      sign_config == :off ->
        [%Message.Empty{}]

      true ->
        Enum.map(sign_context.config_contexts, fn config_context ->
          prediction_message(config_context, sign_context, sign) ||
            service_ended_message(config_context, sign_context) ||
            alert_message(config_context, sign_context, sign) ||
            headway_message(config_context) ||
            early_am_message(config_context, sign_context) ||
            %Message.Empty{}
        end)
    end
    |> transform_messages()
  end

  @spec in_overnight_period?(SignContext.t()) :: boolean()
  def in_overnight_period?(%SignContext{} = sign_context) do
    Enum.all?(sign_context.config_contexts, &overnight_period?(&1, sign_context))
  end

  @spec transform_messages([Message.t()]) :: [Message.t()]
  defp transform_messages([
         %Message.Headway{range: range} = top,
         %Message.Headway{range: range} = bottom
       ]) do
    [
      %Message.Headway{
        destination: nil,
        route: combine_routes(top.route, bottom.route),
        range: range
      }
    ]
  end

  defp transform_messages([
         %Message.Alert{status: status} = top,
         %Message.Alert{status: status} = bottom
       ]) do
    [
      %Message.Alert{
        destination: nil,
        route: combine_routes(top.route, bottom.route),
        status: status,
        uses_shuttles?: top.uses_shuttles?,
        union_square?: top.union_square?
      }
    ]
  end

  defp transform_messages([%Message.ServiceEnded{} = top, %Message.ServiceEnded{} = bottom]) do
    [%Message.ServiceEnded{destination: nil, route: combine_routes(top.route, bottom.route)}]
  end

  defp transform_messages(messages), do: messages

  @spec render_messages([Message.t()]) :: {Content.Message.value(), Content.Message.value()}
  def render_messages([single]) do
    Message.to_multi_line(single)
  end

  def render_messages([top, bottom]) do
    long_top = Message.to_single_line(top, :long)
    long_bottom = Message.to_single_line(bottom, :long)

    cond do
      fits_on_top_line?(long_top) -> {long_top, long_bottom}
      fits_on_top_line?(long_bottom) -> {long_bottom, long_top}
      short_top = Message.to_single_line(top, :short) -> {short_top, long_bottom}
      short_bottom = Message.to_single_line(bottom, :short) -> {short_bottom, long_top}
      true -> paginate(Message.to_full_page(top), Message.to_full_page(bottom))
    end
  end

  defp fits_on_top_line?(content) do
    case content do
      list when is_list(list) -> Enum.map(list, &elem(&1, 0))
      single -> [single]
    end
    |> Enum.all?(&(String.length(&1) <= 18))
  end

  defp combine_routes(route, route), do: route
  defp combine_routes(_, _), do: nil

  defp paginate({first_top, first_bottom}, {second_top, second_bottom}) do
    {[{first_top, 6}, {second_top, 6}], [{first_bottom, 6}, {second_bottom, 6}]}
  end

  defp filter_alert_status(:shuttles_transfer_station, :temporary_terminal), do: :none
  defp filter_alert_status(:suspension_transfer_station, :temporary_terminal), do: :none
  defp filter_alert_status(alert_status, _), do: alert_status

  @spec filter_predictions(ConfigContext.t(), SignContext.t()) ::
          [Predictions.Prediction.t()]
  defp filter_predictions(
         %ConfigContext{predictions: predictions, config: config} = config_context,
         %SignContext{} = sign_context
       ) do
    predictions
    |> Enum.filter(fn p -> p.seconds_until_departure && p.schedule_relationship != :skipped end)
    |> Enum.sort_by(fn prediction ->
      {cond do
         config.terminal? -> 0
         prediction.stopped_at_predicted_stop? -> 0
         true -> 1
       end, prediction.seconds_until_departure, prediction.seconds_until_arrival}
    end)
    |> filter_early_am_predictions(config_context, sign_context)
    |> get_unique_destination_predictions(Signs.Utilities.SourceConfig.single_route(config))
  end

  defp filter_early_am_predictions(
         predictions,
         %ConfigContext{first_scheduled_departure: first_scheduled_departure},
         %SignContext{current_time: current_time}
       ) do
    cond do
      !in_early_am?(current_time, first_scheduled_departure) ->
        predictions

      before_early_am_threshold?(current_time, first_scheduled_departure) ->
        # More than 40 minutes before the first scheduled trip, filter out all predictions.
        []

      true ->
        # Less than 40 minutes before the first scheduled trip, filter out reverse predictions,
        # except for Prudential or Symphony EB
        Enum.reject(
          predictions,
          &(&1.type == :reverse and
              &1.stop_id not in ["70240", "70242"])
        )
    end
  end

  # Take next two predictions, but if the list has multiple destinations, prefer showing
  # distinct ones. This helps e.g. the red line trunk where people may need to know about
  # a particular branch.
  defp get_unique_destination_predictions(predictions, "Green") do
    Enum.take(predictions, 2)
  end

  defp get_unique_destination_predictions(predictions, _) do
    case predictions do
      [msg1, msg2 | rest] ->
        first_destination = Content.Utilities.destination_for_prediction(msg1)

        case Enum.find([msg2 | rest], fn x ->
               Content.Utilities.destination_for_prediction(x) != first_destination and
                 Content.Utilities.canonical_destination?(x)
             end) do
          nil -> [msg1, msg2]
          preferred -> [msg1, preferred]
        end

      messages ->
        messages
    end
  end

  defp in_early_am?(_, nil), do: false

  defp in_early_am?(current_time, scheduled) do
    Timex.between?(
      DateTime.to_time(current_time),
      @early_am_start,
      DateTime.to_time(scheduled),
      inclusive: :start
    )
  end

  defp before_early_am_threshold?(_, nil), do: false

  defp before_early_am_threshold?(current_time, scheduled) do
    Timex.before?(current_time, Timex.shift(scheduled, minutes: @early_am_buffer))
  end

  @spec prediction_message(ConfigContext.t(), SignContext.t(), Signs.Realtime.t()) ::
          Message.t() | nil
  defp prediction_message(
         %ConfigContext{config: config, predictions: predictions} = config_context,
         %SignContext{} = sign_context,
         sign
       ) do
    filtered_predictions = filter_predictions(config_context, sign_context)

    if filtered_predictions != [] do
      %Message.Predictions{
        predictions: filtered_predictions,
        terminal?: config.terminal?,
        special_sign:
          case sign do
            %{pa_ess_loc: "BBOW", text_zone: "e"} ->
              :bowdoin_eastbound

            %{pa_ess_loc: "RJFK", text_zone: "m"} ->
              {:jfk_mezzanine, all_same_stop_id?(predictions)}

            _ ->
              nil
          end
      }
    end
  end

  @spec all_same_stop_id?([Predictions.Prediction.t()]) :: boolean()
  defp all_same_stop_id?(all_predictions) do
    length(Enum.uniq_by(all_predictions, & &1.stop_id)) == 1
  end

  defp early_am_message(
         %ConfigContext{config: config, first_scheduled_departure: first_scheduled_departure},
         %SignContext{current_time: current_time}
       ) do
    if in_early_am?(current_time, first_scheduled_departure) do
      %Message.FirstTrain{
        destination: config.headway_destination,
        scheduled: first_scheduled_departure
      }
    end
  end

  @spec overnight_period?(ConfigContext.t(), SignContext.t()) :: boolean()
  defp overnight_period?(
         %ConfigContext{
           first_scheduled_departure: first_scheduled_departure,
           last_scheduled_departure: last_scheduled_departure,
           service_ended?: false
         },
         _
       )
       when first_scheduled_departure == nil or last_scheduled_departure == nil,
       do: false

  defp overnight_period?(
         %ConfigContext{
           first_scheduled_departure: first_scheduled_departure,
           last_scheduled_departure: last_scheduled_departure,
           service_ended?: false
         },
         %SignContext{current_time: current_time}
       ),
       do:
         calculate_overnight_period(
           last_scheduled_departure,
           current_time,
           first_scheduled_departure
         )

  defp overnight_period?(
         %ConfigContext{
           first_scheduled_departure: first_scheduled_departure,
           most_recent_departure: most_recent_departure,
           service_ended?: true
         },
         %SignContext{current_time: current_time}
       ) do
    calculate_overnight_period(
      most_recent_departure,
      current_time,
      first_scheduled_departure
    )
  end

  defp calculate_overnight_period(
         nil,
         _current_time,
         _first_scheduled_departure
       ),
       do: false

  defp calculate_overnight_period(
         last_time_to_check,
         current_time,
         first_scheduled_departure
       ) do
    # Overnight, schedules might switch to the next day
    # so we just check if we're before the AM period, or if we're after the last time we need to check
    Timex.after?(current_time, Timex.shift(last_time_to_check, minutes: @overnight_buffer)) ||
      before_early_am_threshold?(current_time, first_scheduled_departure)
  end

  defp alert_message(
         %ConfigContext{config: config, alert_status: alert_status} = config_context,
         %SignContext{sign_config: sign_config} = sign_context,
         sign
       ) do
    alert_status = filter_alert_status(alert_status, sign_config)
    route = Signs.Utilities.SourceConfig.single_route(config)
    transfer_alert? = alert_status in [:suspension_transfer_station, :shuttles_transfer_station]
    union_square? = sign.pa_ess_loc == "GUNS"

    cond do
      overnight_period?(config_context, sign_context) ->
        nil

      alert_status in [:shuttles_closed_station, :suspension_closed_station, :station_closure] or
          (union_square? and transfer_alert?) ->
        %Message.Alert{
          route: route,
          destination: config.headway_destination,
          status: alert_status,
          uses_shuttles?: sign.uses_shuttles,
          union_square?: union_square?
        }

      transfer_alert? ->
        %Message.Empty{}

      true ->
        nil
    end
  end

  defp headway_message(%ConfigContext{config: config, headways: headways}) do
    if headways do
      %Message.Headway{
        destination: config.headway_destination,
        range: {headways.range_low, headways.range_high},
        route: Signs.Utilities.SourceConfig.single_route(config)
      }
    end
  end

  defp service_ended_message(
         %ConfigContext{config: config} = config_context,
         %SignContext{} = sign_context
       ) do
    route = Signs.Utilities.SourceConfig.single_route(config)

    if config_context.service_ended? and not in_overnight_period?(sign_context) do
      %Message.ServiceEnded{destination: config.headway_destination, route: route}
    end
  end
end
