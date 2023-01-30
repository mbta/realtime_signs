defmodule Signs.Utilities.Messages do
  @moduledoc """
  Helper functions for deciding which message a sign should
  be displaying
  """

  alias Content.Message.Alert

  @type sign_messages ::
          {{Signs.Utilities.SourceConfig.config() | nil, Content.Message.t()},
           {Signs.Utilities.SourceConfig.config() | nil, Content.Message.t()}}

  @spec get_messages(
          Signs.Realtime.t(),
          Engine.Config.sign_config(),
          DateTime.t(),
          Engine.Alerts.Fetcher.stop_status()
        ) :: sign_messages()
  def get_messages(
        sign,
        sign_config,
        current_time,
        alert_status
      ) do
    cond do
      match?({:static_text, {_, _}}, sign_config) ->
        {:static_text, {line1, line2}} = sign_config

        {{nil, Content.Message.Custom.new(line1, :top)},
         {nil, Content.Message.Custom.new(line2, :bottom)}}

      sign_config == :off ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      sign_config == :headway ->
        get_headway_or_alert_messages(sign, current_time, alert_status)

      true ->
        case Signs.Utilities.Predictions.get_messages(sign) do
          {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}} ->
            get_headway_or_alert_messages(sign, current_time, alert_status)

          {top_message, {nil, %Content.Message.Empty{}}} ->
            bottom_message =
              get_paging_headway_or_alert_messages(
                sign,
                current_time,
                alert_status,
                :bottom
              )

            {top_message, bottom_message}

          {{nil, %Content.Message.Empty{}}, bottom_message} ->
            top_message =
              get_paging_headway_or_alert_messages(
                sign,
                current_time,
                alert_status,
                :top
              )

            {bottom_message, top_message}

          messages ->
            messages
        end
    end
  end

  @spec get_headway_or_alert_messages(
          Signs.Realtime.t(),
          DateTime.t(),
          Engine.Alerts.Fetcher.stop_status()
        ) :: sign_messages()
  defp get_headway_or_alert_messages(sign, current_time, alert_status) do
    case get_alert_messages(alert_status, sign.uses_shuttles) do
      nil -> Signs.Utilities.Headways.get_messages(sign, current_time)
      messages -> messages
    end
  end

  defp has_single_source_list?(%Signs.Realtime{source_config: {_}} = _sign), do: true
  defp has_single_source_list?(_), do: false

  defp get_paging_headway_or_alert_messages(
         sign,
         current_time,
         alert_status,
         line
       ) do
    if has_single_source_list?(sign) do
      {nil, Content.Message.Empty.new()}
    else
      source_config =
        if line == :top do
          %Signs.Realtime{source_config: {top_line_source, _}} = sign
          top_line_source
        else
          %Signs.Realtime{source_config: {_, bottom_line_source}} = sign
          bottom_line_source
        end

      if alert_status == :none do
        Signs.Utilities.Headways.get_paging_message(sign, source_config, current_time)
      else
        get_paging_alert_message(
          alert_status,
          sign.uses_shuttles,
          Signs.Utilities.Headways.source_list_destination(source_config)
        )
      end
    end
  end

  @spec get_alert_messages(Engine.Alerts.Fetcher.stop_status(), boolean()) ::
          sign_messages() | nil
  defp get_alert_messages(alert_status, uses_shuttles) do
    case {alert_status, uses_shuttles} do
      {:shuttles_transfer_station, _} ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      {:shuttles_closed_station, true} ->
        {{nil, %Alert.NoService{}}, {nil, %Alert.UseShuttleBus{}}}

      {:shuttles_closed_station, false} ->
        {{nil, %Alert.NoService{}}, {nil, Content.Message.Empty.new()}}

      {:suspension_transfer_station, _} ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      {:suspension_closed_station, _} ->
        {{nil, %Alert.NoService{}}, {nil, Content.Message.Empty.new()}}

      {:station_closure, _} ->
        {{nil, %Alert.NoService{}}, {nil, Content.Message.Empty.new()}}

      _ ->
        nil
    end
  end

  defp get_paging_alert_message(alert_status, uses_shuttles, destination) do
    case {alert_status, uses_shuttles} do
      {:shuttles_transfer_station, _} ->
        {nil, Content.Message.Empty.new()}

      {:shuttles_closed_station, true} ->
        {nil, %Alert.NoServiceUseShuttle{destination: destination}}

      {:shuttles_closed_station, false} ->
        {nil, %Alert.DestinationNoService{destination: destination}}

      {:suspension_transfer_station, _} ->
        {nil, Content.Message.Empty.new()}

      {:suspension_closed_station, _} ->
        {nil, %Alert.DestinationNoService{destination: destination}}

      {:station_closure, _} ->
        {nil, %Alert.DestinationNoService{destination: destination}}

      _ ->
        nil
    end
  end
end
