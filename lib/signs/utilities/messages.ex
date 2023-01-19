defmodule Signs.Utilities.Messages do
  @moduledoc """
  Helper functions for deciding which message a sign should
  be displaying
  """

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
            {top_message, get_paging_headway_message(sign, current_time)}

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

  # If the sign sources is a single list, then it's most likely going to
  # be redundant to page the headways on the second line so skip it
  defp get_paging_headway_message(
         %Signs.Realtime{source_config: {[_config]}} = _sign,
         _current_time
       ) do
    {nil, %Content.Message.Empty{}}
  end

  defp get_paging_headway_message(
         %Signs.Realtime{source_config: {_, second_line_config}} = sign,
         current_time
       ) do
    Signs.Utilities.Headways.get_paging_message(sign, second_line_config, current_time)
  end

  @spec get_alert_messages(Engine.Alerts.Fetcher.stop_status(), boolean()) ::
          sign_messages() | nil
  defp get_alert_messages(alert_status, uses_shuttles) do
    case {alert_status, uses_shuttles} do
      {:shuttles_transfer_station, _} ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      {:shuttles_closed_station, true} ->
        {{nil, %Content.Message.Alert.NoService{}}, {nil, %Content.Message.Alert.UseShuttleBus{}}}

      {:shuttles_closed_station, false} ->
        {{nil, %Content.Message.Alert.NoService{}}, {nil, Content.Message.Empty.new()}}

      {:suspension_transfer_station, _} ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      {:suspension_closed_station, _} ->
        {{nil, %Content.Message.Alert.NoService{}}, {nil, Content.Message.Empty.new()}}

      {:station_closure, _} ->
        {{nil, %Content.Message.Alert.NoService{}}, {nil, Content.Message.Empty.new()}}

      _ ->
        nil
    end
  end
end
