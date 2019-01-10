defmodule Signs.Utilities.Messages do
  @moduledoc """
  Helper functions for deciding which message a sign should
  be displaying
  """

  def get_messages(sign, enabled?, alert_status) do
    cond do
      !enabled? ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      alert_status == :shuttles_transfer_station ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      alert_status == :shuttles_closed_station ->
        {{nil, %Content.Message.Alert.NoService{mode: :train}},
         {nil, %Content.Message.Alert.UseShuttleBus{}}}

      alert_status == :suspension ->
        {{nil, %Content.Message.Alert.NoService{mode: :none}}, {nil, Content.Message.Empty.new()}}

      true ->
        case Signs.Utilities.Predictions.get_messages(sign) do
          {{nil, %Content.Message.Empty{}}, {nil, %Content.Message.Empty{}}} ->
            Signs.Utilities.Headways.get_messages(sign)

          messages ->
            messages
        end
    end
  end
end
