defmodule Signs.Utilities.Messages do
  @moduledoc """
  Helper functions for deciding which message a sign should
  be displaying
  """

  alias Content.Message.Alert

  @spec get_messages(
          Signs.Realtime.predictions(),
          Signs.Realtime.t(),
          Engine.Config.sign_config(),
          DateTime.t(),
          Engine.Alerts.Fetcher.stop_status(),
          DateTime.t() | {DateTime.t(), DateTime.t()}
        ) :: Signs.Realtime.sign_messages()
  def get_messages(
        predictions,
        sign,
        sign_config,
        current_time,
        alert_status,
        scheduled
      ) do
    messages =
      cond do
        match?({:static_text, {_, _}}, sign_config) ->
          {:static_text, {line1, line2}} = sign_config

          {Content.Message.Custom.new(line1, :top), Content.Message.Custom.new(line2, :bottom)}

        sign_config == :off ->
          {Content.Message.Empty.new(), Content.Message.Empty.new()}

        sign_config == :headway ->
          get_headway_or_alert_messages(sign, current_time, alert_status)

        true ->
          case Signs.Utilities.Predictions.get_messages(predictions, sign) do
            {%Content.Message.Empty{}, %Content.Message.Empty{}} ->
              get_headway_or_alert_messages(sign, current_time, alert_status)

            {top_message, %Content.Message.Empty{}} ->
              {top_message,
               get_paging_headway_or_alert_messages(sign, current_time, alert_status, :bottom)}

            {%Content.Message.Empty{}, bottom_message} ->
              if match?(
                   %Content.Message.Predictions{station_code: "RJFK", zone: "m"},
                   bottom_message
                 ) do
                jfk_umass_headway_paging(bottom_message, sign, current_time, alert_status)
              else
                {bottom_message,
                 get_paging_headway_or_alert_messages(sign, current_time, alert_status, :top)}
              end

            messages ->
              messages
          end
      end

    early_am_status =
      Signs.Utilities.EarlyAmSuppression.get_early_am_state(current_time, scheduled)

    cond do
      early_am_status in [:none, {:none, :none}] ->
        messages

      alert_status in [:none, :alert_along_route] and sign_config == :auto ->
        Signs.Utilities.EarlyAmSuppression.do_early_am_suppression(
          messages,
          current_time,
          early_am_status,
          scheduled,
          sign
        )

      true ->
        messages
    end
  end

  defp jfk_umass_headway_paging(prediction, sign, current_time, alert_status) do
    case get_paging_headway_or_alert_messages(
           sign,
           current_time,
           alert_status,
           :top
         ) do
      %Content.Message.Headways.Paging{destination: destination, range: range} ->
        {%Content.Message.GenericPaging{
           messages: [
             %Content.Message.Headways.Top{
               destination: destination,
               vehicle_type: :train
             },
             %{prediction | zone: nil}
           ]
         },
         %Content.Message.GenericPaging{
           messages: [
             %Content.Message.Headways.Bottom{range: range},
             %Content.Message.PlatformPredictionBottom{
               stop_id: prediction.stop_id,
               minutes: prediction.minutes
             }
           ]
         }}

      message ->
        {message, prediction}
    end
  end

  @spec get_headway_or_alert_messages(
          Signs.Realtime.t(),
          DateTime.t(),
          Engine.Alerts.Fetcher.stop_status()
        ) :: Signs.Realtime.sign_messages()
  defp get_headway_or_alert_messages(sign, current_time, alert_status) do
    get_alert_messages(alert_status, sign) ||
      Signs.Utilities.Headways.get_messages(sign, current_time)
  end

  @spec get_paging_headway_or_alert_messages(
          Signs.Realtime.t(),
          DateTime.t(),
          Engine.Alerts.Fetcher.stop_status(),
          :top | :bottom
        ) :: Signs.Realtime.line_content()
  defp get_paging_headway_or_alert_messages(
         %Signs.Realtime{source_config: {top, bottom}} = sign,
         current_time,
         alert_status,
         line
       ) do
    config = if(line == :top, do: top, else: bottom)

    get_paging_alert_message(alert_status, sign.uses_shuttles, config.headway_destination) ||
      Signs.Utilities.Headways.get_paging_message(sign, config, current_time)
  end

  defp get_paging_headway_or_alert_messages(_, _, _, _) do
    Content.Message.Empty.new()
  end

  @spec get_alert_messages(Engine.Alerts.Fetcher.stop_status(), Signs.Realtime.t()) ::
          Signs.Realtime.sign_messages() | nil
  defp get_alert_messages(alert_status, sign) do
    sign_routes = Signs.Utilities.SourceConfig.sign_routes(sign.source_config)

    case {alert_status, sign.uses_shuttles} do
      {:shuttles_transfer_station, _} ->
        {Content.Message.Empty.new(), Content.Message.Empty.new()}

      {:shuttles_closed_station, true} ->
        {%Alert.NoService{routes: sign_routes}, %Alert.UseShuttleBus{}}

      {:shuttles_closed_station, false} ->
        {%Alert.NoService{routes: sign_routes}, Content.Message.Empty.new()}

      {:suspension_transfer_station, _} ->
        {Content.Message.Empty.new(), Content.Message.Empty.new()}

      {:suspension_closed_station, _} ->
        {%Alert.NoService{routes: sign_routes}, Content.Message.Empty.new()}

      {:station_closure, _} ->
        {%Alert.NoService{routes: sign_routes}, Content.Message.Empty.new()}

      _ ->
        nil
    end
  end

  defp get_paging_alert_message(alert_status, uses_shuttles, destination) do
    case {alert_status, uses_shuttles} do
      {:shuttles_transfer_station, _} ->
        Content.Message.Empty.new()

      {:shuttles_closed_station, true} ->
        %Alert.NoServiceUseShuttle{destination: destination}

      {:shuttles_closed_station, false} ->
        %Alert.DestinationNoService{destination: destination}

      {:suspension_transfer_station, _} ->
        Content.Message.Empty.new()

      {:suspension_closed_station, _} ->
        %Alert.DestinationNoService{destination: destination}

      {:station_closure, _} ->
        %Alert.DestinationNoService{destination: destination}

      _ ->
        nil
    end
  end

  @spec same_content?(Content.Message.t(), Content.Message.t()) :: boolean()
  def same_content?(sign_msg, new_msg) do
    sign_msg == new_msg or countup?(sign_msg, new_msg)
  end

  defp countup?(
         %Content.Message.Predictions{destination: same, minutes: :arriving},
         %Content.Message.Predictions{destination: same, minutes: :approaching}
       ) do
    true
  end

  defp countup?(
         %Content.Message.Predictions{destination: same, minutes: :approaching},
         %Content.Message.Predictions{destination: same, minutes: 1}
       ) do
    true
  end

  defp countup?(
         %Content.Message.Predictions{destination: same, minutes: a},
         %Content.Message.Predictions{destination: same, minutes: b}
       )
       when a + 1 == b do
    true
  end

  defp countup?(_sign, _new) do
    false
  end
end
