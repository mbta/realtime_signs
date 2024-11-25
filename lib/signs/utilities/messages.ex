defmodule Signs.Utilities.Messages do
  @moduledoc """
  Helper functions for deciding which message a sign should
  be displaying
  """

  alias Content.Message.Alert
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

        {Content.Message.Custom.new(line1, :top), Content.Message.Custom.new(line2, :bottom)}

      sign_config == :off ->
        {%Content.Message.Empty{}, %Content.Message.Empty{}}

      match?(%{source_config: {_, _}}, sign) ->
        Enum.zip([
          Tuple.to_list(sign.source_config),
          Tuple.to_list(predictions),
          Tuple.to_list(alert_status),
          Tuple.to_list(scheduled),
          Tuple.to_list(service_status)
        ])
        |> Enum.map(fn {config, predictions, alert_status, scheduled, service_status} ->
          predictions =
            filter_predictions(predictions, config, sign_config, current_time, scheduled)

          alert_status = filter_alert_status(alert_status, sign_config)

          Signs.Utilities.Predictions.prediction_message(predictions, config, sign) ||
            service_ended_message(service_status, config) ||
            alert_message(alert_status, sign, config) ||
            Signs.Utilities.Headways.headway_message(sign, config, current_time) ||
            early_am_message(current_time, scheduled, config) ||
            %Content.Message.Empty{}
        end)
        |> List.to_tuple()
        |> transform_messages()

      true ->
        config = sign.source_config

        predictions =
          filter_predictions(predictions, config, sign_config, current_time, scheduled)

        alert_status = filter_alert_status(alert_status, sign_config)

        Signs.Utilities.Predictions.prediction_messages(predictions, config, sign) ||
          service_ended_messages(service_status, config) ||
          alert_messages(alert_status, sign, config) ||
          Signs.Utilities.Headways.headway_messages(sign, config, current_time) ||
          early_am_messages(current_time, scheduled, config) ||
          {%Content.Message.Empty{}, %Content.Message.Empty{}}
    end
  end

  @spec transform_messages(Signs.Realtime.sign_messages()) :: Signs.Realtime.sign_messages()
  defp transform_messages(
         {%Content.Message.Headways.Paging{range: range, route: top_route},
          %Content.Message.Headways.Paging{range: range, route: bottom_route}}
       ) do
    {%Content.Message.Headways.Top{route: combine_routes(top_route, bottom_route)},
     %Content.Message.Headways.Bottom{range: range}}
  end

  defp transform_messages(
         {%Content.Message.Alert.DestinationNoService{route: top_route},
          %Content.Message.Alert.DestinationNoService{route: bottom_route}}
       ) do
    {%Content.Message.Alert.NoService{route: combine_routes(top_route, bottom_route)},
     %Content.Message.Empty{}}
  end

  defp transform_messages(
         {%Content.Message.Alert.NoServiceUseShuttle{route: top_route},
          %Content.Message.Alert.NoServiceUseShuttle{route: bottom_route}}
       ) do
    {%Content.Message.Alert.NoService{route: combine_routes(top_route, bottom_route)},
     %Alert.UseShuttleBus{}}
  end

  defp transform_messages(
         {%Content.Message.LastTrip.NoService{route: top_route},
          %Content.Message.LastTrip.NoService{route: bottom_route}}
       ) do
    {%Content.Message.LastTrip.StationClosed{route: combine_routes(top_route, bottom_route)},
     %Content.Message.LastTrip.ServiceEnded{}}
  end

  defp transform_messages({top, bottom}) do
    cond do
      fits_on_top_line?(top) -> {top, bottom}
      fits_on_top_line?(bottom) -> {bottom, top}
      can_shrink?(top) -> {%{top | variant: :short}, bottom}
      can_shrink?(bottom) -> {%{bottom | variant: :short}, top}
      true -> paginate(expand_message(top), expand_message(bottom))
    end
  end

  defp fits_on_top_line?(message) do
    case Content.Message.to_string(message) do
      list when is_list(list) -> Enum.map(list, &elem(&1, 0))
      single -> [single]
    end
    |> Enum.all?(&(String.length(&1) <= 18))
  end

  defp can_shrink?(message), do: Map.has_key?(message, :variant)

  defp combine_routes(route, route), do: route
  defp combine_routes(_, _), do: nil

  @spec expand_message(Content.Message.t()) :: Signs.Realtime.sign_messages()
  defp expand_message(%Content.Message.Headways.Paging{
         range: range,
         route: route,
         destination: destination
       }) do
    {%Content.Message.Headways.Top{route: route, destination: destination},
     %Content.Message.Headways.Bottom{range: range}}
  end

  defp expand_message(
         %Content.Message.Predictions{
           special_sign: :jfk_mezzanine,
           prediction: %{stop_id: stop_id},
           minutes: minutes
         } = prediction
       ) do
    {%{prediction | special_sign: nil},
     %Content.Message.PlatformPredictionBottom{stop_id: stop_id, minutes: minutes}}
  end

  defp expand_message(%Content.Message.EarlyAm.DestinationScheduledTime{
         destination: destination,
         scheduled_time: scheduled_time
       }) do
    {%Content.Message.EarlyAm.DestinationTrain{destination: destination},
     %Content.Message.EarlyAm.ScheduledTime{scheduled_time: scheduled_time}}
  end

  defp expand_message(%Content.Message.Alert.NoServiceUseShuttle{
         route: route,
         destination: destination
       }) do
    {%Content.Message.Alert.NoService{destination: destination, route: route},
     %Alert.UseShuttleBus{}}
  end

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
    |> then(fn predictions -> if(sign_config == :headway, do: [], else: predictions) end)
    |> then(fn predictions ->
      case {in_early_am?(current_time, scheduled),
            before_early_am_threshold?(current_time, scheduled)} do
        {false, _} ->
          predictions

        {true, true} ->
          # More than 40 minutes before the first scheduled trip, filter out all predictions.
          []

        {true, false} ->
          # Less than 40 minutes before the first scheduled trip, filter out reverse predictions,
          # except for Prudential or Symphony EB
          Enum.reject(
            predictions,
            &(Signs.Utilities.Predictions.reverse_prediction?(&1, config.terminal?) and
                &1.stop_id not in ["70240", "70242"])
          )
      end
    end)
  end

  defp in_early_am?(_, nil), do: false

  defp in_early_am?(current_time, scheduled) do
    Timex.between?(DateTime.to_time(current_time), @early_am_start, DateTime.to_time(scheduled))
  end

  defp before_early_am_threshold?(_, nil), do: false

  defp before_early_am_threshold?(current_time, scheduled) do
    Timex.before?(current_time, Timex.shift(scheduled, minutes: @early_am_buffer))
  end

  defp early_am_message(current_time, scheduled_time, config) do
    if in_early_am?(current_time, scheduled_time) do
      %Content.Message.EarlyAm.DestinationScheduledTime{
        destination: config.headway_destination,
        scheduled_time: scheduled_time
      }
    end
  end

  defp early_am_messages(current_time, scheduled_time, config) do
    if in_early_am?(current_time, scheduled_time) do
      {%Content.Message.EarlyAm.DestinationTrain{destination: config.headway_destination},
       %Content.Message.EarlyAm.ScheduledTime{scheduled_time: scheduled_time}}
    end
  end

  defp alert_messages(alert_status, %{pa_ess_loc: "GUNS"}, config) do
    route = Signs.Utilities.SourceConfig.single_route(config)
    destination = config.headway_destination

    if alert_status in [:none, :alert_along_route],
      do: nil,
      else: {%Alert.NoService{route: route, destination: destination}, %Alert.UseRoutes{}}
  end

  defp alert_messages(alert_status, sign, config) do
    route = Signs.Utilities.SourceConfig.single_route(config)
    destination = config.headway_destination

    case {alert_status, sign.uses_shuttles} do
      {:shuttles_transfer_station, _} ->
        {%Content.Message.Empty{}, %Content.Message.Empty{}}

      {:shuttles_closed_station, true} ->
        {%Alert.NoService{route: route, destination: destination}, %Alert.UseShuttleBus{}}

      {:shuttles_closed_station, false} ->
        {%Alert.NoService{route: route, destination: destination}, %Content.Message.Empty{}}

      {:suspension_transfer_station, _} ->
        {%Content.Message.Empty{}, %Content.Message.Empty{}}

      {:suspension_closed_station, _} ->
        {%Alert.NoService{route: route, destination: destination}, %Content.Message.Empty{}}

      {:station_closure, _} ->
        {%Alert.NoService{route: route, destination: destination}, %Content.Message.Empty{}}

      _ ->
        nil
    end
  end

  defp alert_message(alert_status, sign, config) do
    route = Signs.Utilities.SourceConfig.single_route(config)

    case {alert_status, sign.uses_shuttles} do
      {:shuttles_transfer_station, _} ->
        %Content.Message.Empty{}

      {:shuttles_closed_station, true} ->
        %Alert.NoServiceUseShuttle{route: route, destination: config.headway_destination}

      {:shuttles_closed_station, false} ->
        %Alert.DestinationNoService{route: route, destination: config.headway_destination}

      {:suspension_transfer_station, _} ->
        %Content.Message.Empty{}

      {:suspension_closed_station, _} ->
        %Alert.DestinationNoService{route: route, destination: config.headway_destination}

      {:station_closure, _} ->
        %Alert.DestinationNoService{route: route, destination: config.headway_destination}

      _ ->
        nil
    end
  end

  defp service_ended_message(service_ended?, config) do
    route = Signs.Utilities.SourceConfig.single_route(config)

    if service_ended? do
      %Content.Message.LastTrip.NoService{destination: config.headway_destination, route: route}
    end
  end

  defp service_ended_messages(service_ended?, config) do
    if service_ended? do
      {%Content.Message.LastTrip.PlatformClosed{destination: config.headway_destination},
       %Content.Message.LastTrip.ServiceEnded{destination: config.headway_destination}}
    end
  end
end
