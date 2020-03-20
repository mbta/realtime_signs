defmodule Signs.Utilities.Messages do
  @moduledoc """
  Helper functions for deciding which message a sign should
  be displaying
  """

  @spec get_messages(
          Signs.Realtime.t(),
          Engine.Config.sign_config(),
          DateTime.t(),
          Engine.Alerts.Fetcher.stop_status()
        ) ::
          {{Signs.Utilities.SourceConfig.config() | nil, Content.Message.t()},
           {Signs.Utilities.SourceConfig.config() | nil, Content.Message.t()}}
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

          messages ->
            messages
        end
    end
  end

  @spec get_headway_or_alert_messages(
          Signs.Realtime.t(),
          DateTime.t(),
          Engine.Alerts.Fetcher.stop_status()
        ) ::
          {{Signs.Utilities.SourceConfig.config() | nil, Content.Message.t()},
           {Signs.Utilities.SourceConfig.config() | nil, Content.Message.t()}}
  defp get_headway_or_alert_messages(sign, current_time, alert_status) do
    case get_alert_messages(alert_status) do
      nil -> Signs.Utilities.Headways.get_messages(sign, current_time)
      messages -> messages
    end
  end

  @spec get_alert_messages(Engine.Alerts.Fetcher.stop_status()) ::
          {{Signs.Utilities.SourceConfig.config() | nil, Content.Message.t()},
           {Signs.Utilities.SourceConfig.config() | nil, Content.Message.t()}}
          | nil
  defp get_alert_messages(alert_status) do
    case alert_status do
      :shuttles_transfer_station ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      :shuttles_closed_station ->
        {{nil, %Content.Message.Alert.NoService{}}, {nil, %Content.Message.Alert.UseShuttleBus{}}}

      :suspension_transfer_station ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      :suspension_closed_station ->
        {{nil, %Content.Message.Alert.NoService{}}, {nil, Content.Message.Empty.new()}}

      :station_closure ->
        {{nil, %Content.Message.Alert.NoService{}}, {nil, Content.Message.Empty.new()}}

      _ ->
        nil
    end
  end
end
