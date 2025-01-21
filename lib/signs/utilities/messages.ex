defmodule Signs.Utilities.Messages do
  @moduledoc """
  Helper functions for deciding which message a sign should
  be displaying
  """

  @early_am_start ~T[03:29:00]
  @early_am_buffer -40

  @spec get_messages(
          Signs.Realtime.predictions(),
          Signs.Realtime.t(),
          Engine.Config.sign_config(),
          DateTime.t(),
          Engine.Alerts.Fetcher.stop_status()
          | {Engine.Alerts.Fetcher.stop_status(), Engine.Alerts.Fetcher.stop_status()},
          DateTime.t() | {DateTime.t(), DateTime.t()},
          boolean() | {boolean(), boolean()}
        ) :: Signs.Realtime.sign_messages()
  def get_messages(
        predictions,
        sign,
        sign_config,
        current_time,
        alert_status,
        scheduled,
        service_status
      ) do
    cond do
      match?({:static_text, {_, _}}, sign_config) ->
        {:static_text, {line1, line2}} = sign_config
        [%Message.Custom{top: line1, bottom: line2}]

      sign_config == :off ->
        [%Message.Empty{}]

      true ->
        if match?(%{source_config: {_, _}}, sign) do
          Enum.zip([
            Tuple.to_list(sign.source_config),
            Tuple.to_list(predictions),
            Tuple.to_list(alert_status),
            Tuple.to_list(scheduled),
            Tuple.to_list(service_status)
          ])
        else
          [{sign.source_config, predictions, alert_status, scheduled, service_status}]
        end
        |> Enum.map(fn {config, predictions, alert_status, scheduled, service_status} ->
          predictions =
            filter_predictions(predictions, config, sign_config, current_time, scheduled)

          alert_status = filter_alert_status(alert_status, sign_config)

          prediction_message(predictions, config, sign) ||
            service_ended_message(service_status, config) ||
            alert_message(alert_status, sign, config) ||
            Signs.Utilities.Headways.headway_message(config, current_time) ||
            early_am_message(current_time, scheduled, config) ||
            %Message.Empty{}
        end)
    end
    |> transform_messages()
    |> render_messages()
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

  defp render_messages([single]) do
    Message.to_multi_line(single)
  end

  defp render_messages([top, bottom]) do
    cond do
      fits_on_top_line?(top) ->
        {Message.to_single_line(top), Message.to_single_line(bottom)}

      fits_on_top_line?(bottom) ->
        {Message.to_single_line(bottom), Message.to_single_line(top)}

      can_shrink?(top) ->
        {%{Message.to_single_line(top) | variant: :short}, Message.to_single_line(bottom)}

      can_shrink?(bottom) ->
        {%{Message.to_single_line(bottom) | variant: :short}, Message.to_single_line(top)}

      true ->
        paginate(Message.to_full_page(top), Message.to_full_page(bottom))
    end
  end

  defp fits_on_top_line?(message) do
    case Message.to_single_line(message) |> Content.Message.to_string() do
      list when is_list(list) -> Enum.map(list, &elem(&1, 0))
      single -> [single]
    end
    |> Enum.all?(&(String.length(&1) <= 18))
  end

  defp can_shrink?(message), do: Message.to_single_line(message) |> Map.has_key?(:variant)

  defp combine_routes(route, route), do: route
  defp combine_routes(_, _), do: nil

  defp paginate({first_top, first_bottom}, {second_top, second_bottom}) do
    {%Content.Message.GenericPaging{messages: [first_top, second_top]},
     %Content.Message.GenericPaging{messages: [first_bottom, second_bottom]}}
  end

  defp filter_alert_status(:shuttles_transfer_station, :temporary_terminal), do: :none
  defp filter_alert_status(:suspension_transfer_station, :temporary_terminal), do: :none
  defp filter_alert_status(alert_status, _), do: alert_status

  @spec filter_predictions(
          [Predictions.Prediction.t()],
          Signs.Utilities.SourceConfig.config(),
          Engine.Config.sign_config(),
          DateTime.t(),
          DateTime.t()
        ) :: [Predictions.Prediction.t()]
  defp filter_predictions(predictions, config, sign_config, current_time, scheduled) do
    predictions
    |> Enum.filter(fn p -> p.seconds_until_departure && p.schedule_relationship != :skipped end)
    |> Enum.sort_by(fn prediction ->
      {cond do
         config.terminal? -> 0
         prediction.stopped_at_predicted_stop? -> 0
         true -> 1
       end, prediction.seconds_until_departure, prediction.seconds_until_arrival}
    end)
    |> then(fn predictions -> if(sign_config == :headway, do: [], else: predictions) end)
    |> filter_early_am_predictions(current_time, scheduled)
    |> filter_large_red_line_gaps()
    |> get_unique_destination_predictions(Signs.Utilities.SourceConfig.single_route(config))
  end

  defp filter_early_am_predictions(predictions, current_time, scheduled) do
    cond do
      !in_early_am?(current_time, scheduled) ->
        predictions

      before_early_am_threshold?(current_time, scheduled) ->
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

  # This is a temporary fix for a situation where spotty train sheet data can
  # cause some predictions to not show up until right before they leave the
  # terminal. This makes it appear that the next train will be much later than
  # it is. At stations near Ashmont and Braintree, we're discarding any
  # predictions following a gap of more than 21 minutes from the previous one,
  # since this is a reasonable indicator of this problem.
  defp filter_large_red_line_gaps([first | _] = predictions)
       when first.stop_id in ~w(70105 Braintree-01 Braintree-02 70104 70102 70100 70094 70092 70090 70088 70098 70086 70096) do
    [%{seconds_until_departure: 0} | predictions]
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.take_while(fn [prev, current] ->
      current.seconds_until_departure - prev.seconds_until_departure < 21 * 60
    end)
    |> Enum.map(&List.last/1)
  end

  defp filter_large_red_line_gaps(predictions), do: predictions

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
               Content.Utilities.destination_for_prediction(x) != first_destination
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
    Timex.between?(DateTime.to_time(current_time), @early_am_start, DateTime.to_time(scheduled))
  end

  defp before_early_am_threshold?(_, nil), do: false

  defp before_early_am_threshold?(current_time, scheduled) do
    Timex.before?(current_time, Timex.shift(scheduled, minutes: @early_am_buffer))
  end

  @spec prediction_message(
          [Predictions.Prediction.t()],
          Signs.Utilities.SourceConfig.config(),
          Signs.Realtime.t()
        ) :: Message.t() | nil
  defp prediction_message(predictions, %{terminal?: terminal?}, sign) do
    if predictions != [] do
      %Message.Predictions{
        predictions: predictions,
        terminal?: terminal?,
        special_sign:
          case sign do
            %{pa_ess_loc: "RJFK", text_zone: "m"} -> :jfk_mezzanine
            %{pa_ess_loc: "BBOW", text_zone: "e"} -> :bowdoin_eastbound
            _ -> nil
          end
      }
    end
  end

  defp early_am_message(current_time, scheduled_time, config) do
    if in_early_am?(current_time, scheduled_time) do
      %Message.FirstTrain{destination: config.headway_destination, scheduled: scheduled_time}
    end
  end

  defp alert_message(alert_status, sign, config) do
    route = Signs.Utilities.SourceConfig.single_route(config)
    transfer_alert? = alert_status in [:suspension_transfer_station, :shuttles_transfer_station]
    union_square? = sign.pa_ess_loc == "GUNS"

    cond do
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

  defp service_ended_message(service_ended?, config) do
    route = Signs.Utilities.SourceConfig.single_route(config)

    if service_ended? do
      %Message.ServiceEnded{destination: config.headway_destination, route: route}
    end
  end
end
