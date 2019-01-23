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

      alert_status == :shuttles_closed_station ->
        {{nil, %Content.Message.Alert.NoService{mode: :train}},
         {nil, %Content.Message.Alert.UseShuttleBus{}}}

      alert_status == :suspension ->
        {{nil, %Content.Message.Alert.NoService{mode: :none}}, {nil, Content.Message.Empty.new()}}

      true ->
        case Signs.Utilities.Predictions.get_messages(sign) do
          {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}} ->
            if alert_status == :shuttles_transfer_station do
              Logger.info("shuttle_transfer_station: get messages empty and this is a transfer")
              {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
            else
              Logger.info(
                "shuttle_transfer_station: get messages empty and this is a not transfer"
              )

              Signs.Utilities.Headways.get_messages(sign)
            end

          messages ->
            Logger.info("shuttle_transfer_station: get messages not empty")
            messages
        end
    end
  end
end
