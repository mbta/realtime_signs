defmodule Signs.Utilities.Messages do
  @moduledoc """
  Helper functions for deciding which message a sign should
  be displaying
  """

  alias Content.Message.Alert

  @spec get_messages(
          Signs.Realtime.t(),
          Engine.Config.sign_config(),
          DateTime.t(),
          Engine.Alerts.Fetcher.stop_status()
        ) :: Signs.Realtime.sign_messages()
  def get_messages(sign, sign_config, current_time, alert_status) do
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
            {top_message,
             get_paging_headway_or_alert_messages(sign, current_time, alert_status, :bottom)}

          {{nil, %Content.Message.Empty{}}, bottom_message} ->
            {bottom_message,
             get_paging_headway_or_alert_messages(sign, current_time, alert_status, :top)}

          messages ->
            messages
        end
    end
  end

  @spec get_headway_or_alert_messages(
          Signs.Realtime.t(),
          DateTime.t(),
          Engine.Alerts.Fetcher.stop_status()
        ) :: Signs.Realtime.sign_messages()
  defp get_headway_or_alert_messages(sign, current_time, alert_status) do
    get_alert_messages(alert_status, sign.uses_shuttles) ||
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
    {nil, Content.Message.Empty.new()}
  end

  @spec get_alert_messages(Engine.Alerts.Fetcher.stop_status(), boolean()) ::
          Signs.Realtime.sign_messages() | nil
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
