defmodule Signs.Utilities.Predictions do
  @moduledoc """
  Given a sign with a SourceConfig, fetches all relevant predictions and
  combines and sorts them, eventually returning the two relevent messages
  for the top and bottom lines.
  """

  alias Signs.Utilities.SourceConfig

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
    |> Enum.sort(fn {s1, p1}, {s2, p2} ->
      p1_time = if s1.terminal?, do: p1.seconds_until_departure, else: p1.seconds_until_arrival
      p2_time = if s2.terminal?, do: p2.seconds_until_departure, else: p2.seconds_until_arrival
      p1_time < p2_time
    end)
    |> Enum.take(2)
    |> Enum.with_index()
    |> Enum.map(fn {{source, prediction}, i} ->
      stopped_at? = i == 0 and prediction_engine.stopped_at?(source.stop_id)

      cond do
        stopped_train?(prediction) ->
          {source, Content.Message.StoppedTrain.from_prediction(prediction)}

        source.terminal? ->
          {source, Content.Message.Predictions.terminal(prediction, stopped_at?)}

        true ->
          {source, Content.Message.Predictions.non_terminal(prediction, stopped_at?)}
      end
    end)
    |> case do
      [] -> {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}
      [msg] -> {msg, {nil, Content.Message.Empty.new()}}
      [msg1, msg2] -> {msg1, msg2}
    end
  end

  defp stopped_train?(prediction) do
    enabled? = Application.get_env(:realtime_signs, :stopped_train_enabled?)
    status = prediction.boarding_status
    enabled? && status && String.starts_with?(status, "Stopped")
  end
end
