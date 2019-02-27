defmodule Signs.Utilities.Messages do
  @moduledoc """
  Helper functions for deciding which message a sign should
  be displaying
  """

  @spec get_messages(
          Signs.Realtime.t(),
          boolean(),
          Engine.Alerts.Fetcher.stop_status(),
          {String.t(), String.t()} | nil
        ) ::
          {{Signs.Utilities.SourceConfig.config() | nil, Content.Message.t()},
           {Signs.Utilities.SourceConfig.config() | nil, Content.Message.t()}}
  def get_messages(sign, enabled?, alert_status, custom_text) do
    cond do
      custom_text != nil ->
        {line1, line2} = custom_text

        {{nil, Content.Message.Custom.new(line1, :top)},
         {nil, Content.Message.Custom.new(line2, :bottom)}}

      !enabled? ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      true ->
        case Signs.Utilities.Predictions.get_messages(sign) do
          {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}} ->
            case alert_status do
              :shuttles_transfer_station ->
                {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

              :shuttles_closed_station ->
                {{nil, %Content.Message.Alert.NoService{mode: :train}},
                 {nil, %Content.Message.Alert.UseShuttleBus{}}}

              :suspension_transfer_station ->
                {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

              :suspension_closed_station ->
                {{nil, %Content.Message.Alert.NoService{mode: :train}},
                 {nil, Content.Message.Empty.new()}}

              :station_closure ->
                {{nil, %Content.Message.Alert.NoService{mode: :train}},
                 {nil, Content.Message.Empty.new()}}

              _ ->
                Signs.Utilities.Headways.get_messages(sign)
            end

          messages ->
            messages
        end
    end
  end
end
