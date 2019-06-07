defmodule Signs.Utilities.Messages do
  @moduledoc """
  Helper functions for deciding which message a sign should
  be displaying
  """

  @spec get_messages(
          Signs.Realtime.t(),
          boolean(),
          Engine.Alerts.Fetcher.stop_status(),
          {String.t(), String.t()} | nil,
          Content.Message.Alert.NoService.transit_mode(),
          {Engine.Bridge.status(), Engine.Bridge.duration()} | nil
        ) ::
          {{Signs.Utilities.SourceConfig.config() | nil, Content.Message.t()},
           {Signs.Utilities.SourceConfig.config() | nil, Content.Message.t()}}
  def get_messages(sign, enabled?, alert_status, custom_text, mode, bridge_state) do
    cond do
      custom_text != nil ->
        {line1, line2} = custom_text

        {{nil, Content.Message.Custom.new(line1, :top)},
         {nil, Content.Message.Custom.new(line2, :bottom)}}

      !enabled? ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      alert_status == :none and match?({"Raised", _}, bridge_state) ->
        {"Raised", duration} = bridge_state

        {{nil, %Content.Message.Bridge.Delays{}},
         {nil, duration |> clean_duration |> Content.Message.Bridge.Up.new()}}

      true ->
        case Signs.Utilities.Predictions.get_messages(sign) do
          {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}} ->
            case alert_status do
              :shuttles_transfer_station ->
                {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

              :shuttles_closed_station ->
                {{nil, %Content.Message.Alert.NoService{mode: mode}},
                 {nil, %Content.Message.Alert.UseShuttleBus{}}}

              :suspension_transfer_station ->
                {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

              :suspension_closed_station ->
                {{nil, %Content.Message.Alert.NoService{mode: mode}},
                 {nil, Content.Message.Empty.new()}}

              :station_closure ->
                {{nil, %Content.Message.Alert.NoService{mode: mode}},
                 {nil, Content.Message.Empty.new()}}

              _ ->
                Signs.Utilities.Headways.get_messages(sign)
            end

          messages ->
            messages
        end
    end
  end

  @spec clean_duration(integer() | nil) :: integer() | nil
  defp clean_duration(n) when is_integer(n) and n >= 1, do: n
  defp clean_duration(_), do: nil
end
