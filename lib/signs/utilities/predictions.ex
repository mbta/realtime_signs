defmodule Signs.Utilities.Predictions do
  @moduledoc """
  Given a sign with a SourceConfig, fetches all relevant predictions and
  combines and sorts them, eventually returning the two relevent messages
  for the top and bottom lines.
  """

  alias Signs.Utilities.SourceConfig
  alias Content.Message.Predictions, as: P

  @spec get_messages(Signs.Realtime.t(), boolean()) ::
          {{SourceConfig.source() | nil, Content.Message.t()},
           {SourceConfig.source() | nil, Content.Message.t()}}
  def get_messages(_sign, false) do
    {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
  end

  def get_messages(%{source_config: {top_line_sources, bottom_line_sources}} = sign, true) do
    {top, _} = get_predictions(sign.prediction_engine, top_line_sources)
    {bottom, _} = get_predictions(sign.prediction_engine, bottom_line_sources)
    {top, bottom}
  end

  def get_messages(%{source_config: {both_lines_sources}} = sign, true) do
    get_predictions(sign.prediction_engine, both_lines_sources)
  end

  defp get_predictions(prediction_engine, source_list) do
    source_list
    |> Enum.flat_map(fn source ->
      source.stop_id
      |> prediction_engine.for_stop(source.direction_id)
      |> Enum.filter(&(source.routes == nil or &1.route_id in source.routes))
      |> Enum.map(&{source, &1})
    end)
    |> Enum.filter(fn {_, p} ->
      p.seconds_until_departure
    end)
    |> Enum.sort(fn {_s1, p1}, {_s2, p2} ->
      p1_time = p1.seconds_until_arrival || p1.seconds_until_departure
      p2_time = p2.seconds_until_arrival || p2.seconds_until_departure

      case {p1.stops_away, p2.stops_away} do
        {0, 0} ->
          p1_time < p2_time

        {0, _} ->
          true

        {_, 0} ->
          false

        {_, _} ->
          p1_time < p2_time
      end
    end)
    |> Enum.take(2)
    |> Enum.map(fn {source, prediction} ->
      cond do
        stopped_train?(prediction) ->
          {source, Content.Message.StoppedTrain.from_prediction(prediction)}

        source.terminal? ->
          {source, Content.Message.Predictions.terminal(prediction)}

        true ->
          {source, Content.Message.Predictions.non_terminal(prediction)}
      end
    end)
    |> case do
      [] ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      [msg] ->
        {msg, {nil, Content.Message.Empty.new()}}

      [{s1, %P{minutes: :arriving}} = msg1, {s2, %P{minutes: :arriving} = p2} = msg2] ->
        if allowed_multi_berth_platform?(s1, s2) do
          {msg1, msg2}
        else
          {msg1, {s2, %{p2 | minutes: 1}}}
        end

      [msg1, msg2] -> {msg1, msg2}
    end
  end

  defp stopped_train?(prediction) do
    enabled? = Application.get_env(:realtime_signs, :stopped_train_enabled?)
    status = prediction.boarding_status
    enabled? && status && String.starts_with?(status, "Stopped")
  end

  defp allowed_multi_berth_platform?(
      %SourceConfig{multi_berth?: true} = s1,
      %SourceConfig{multi_berth?: true} = s2
    ) when s1 != s2 do
    true
  end

  defp allowed_multi_berth_platform?(_, _) do
    false
  end
end
