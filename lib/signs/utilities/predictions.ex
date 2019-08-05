defmodule Signs.Utilities.Predictions do
  @moduledoc """
  Given a sign with a SourceConfig, fetches all relevant predictions and
  combines and sorts them, eventually returning the two relevent messages
  for the top and bottom lines.
  """

  require Logger
  require Content.Utilities
  alias Signs.Utilities.SourceConfig

  @spec get_messages(Signs.Realtime.t()) ::
          {{SourceConfig.source() | nil, Content.Message.t()},
           {SourceConfig.source() | nil, Content.Message.t()}}
  def get_messages(%{source_config: {top_line_sources, bottom_line_sources}} = sign) do
    {top, _} = get_predictions(sign.prediction_engine, top_line_sources)
    {bottom, _} = get_predictions(sign.prediction_engine, bottom_line_sources)
    {top, bottom}
  end

  def get_messages(%{source_config: {both_lines_sources}} = sign) do
    get_predictions(sign.prediction_engine, both_lines_sources)
  end

  @spec get_predictions(module(), [Signs.Utilities.SourceConfig.source()]) ::
          {{SourceConfig.source() | nil, Content.Message.t()},
           {SourceConfig.source() | nil, Content.Message.t()}}
  defp get_predictions(prediction_engine, source_list) do
    source_list
    |> get_source_list_predictions(prediction_engine)
    |> Enum.filter(fn {_, p} ->
      p.seconds_until_departure
    end)
    |> Enum.sort_by(fn {_source_config, prediction} ->
      {case prediction.stops_away do
         0 -> 0
         _ -> 1
       end, prediction.seconds_until_departure, prediction.seconds_until_arrival}
    end)
    |> Enum.take(2)
    |> Enum.map(fn {source, prediction} ->
      cond do
        red_line_stops_away?(prediction) ->
          {source, Content.Message.StopsAway.from_prediction(prediction)}

        stopped_train?(prediction) ->
          {source, Content.Message.StoppedTrain.from_prediction(prediction)}

        source.terminal? ->
          {source, Content.Message.Predictions.terminal(prediction)}

        true ->
          {source, Content.Message.Predictions.non_terminal(prediction)}
      end
    end)
    |> sort_messages_by_stops_away()
    |> case do
      [] ->
        {{nil, Content.Message.Empty.new()}, {nil, Content.Message.Empty.new()}}

      [msg] ->
        {msg, {nil, Content.Message.Empty.new()}}

      [
        {s1, %Content.Message.Predictions{minutes: :arriving}} = msg1,
        {s2, %Content.Message.Predictions{minutes: :arriving} = p2} = msg2
      ] ->
        if allowed_multi_berth_platform?(s1, s2) do
          {msg1, msg2}
        else
          {msg1, {s2, %{p2 | minutes: 1}}}
        end

      [msg1, msg2] ->
        {msg1, msg2}
    end
  end

  @spec get_passthrough_train_audio(Signs.Realtime.t()) :: Content.Audio.t() | nil
  def get_passthrough_train_audio(%Signs.Realtime{source_config: {single_source}} = sign) do
    single_source
    |> get_source_list_predictions(sign.prediction_engine)
    |> Enum.filter(fn {_source, prediction} ->
      prediction.seconds_until_passthrough && prediction.seconds_until_passthrough <= 60
    end)
    |> Enum.sort_by(fn {_source, prediction} -> prediction.seconds_until_passthrough end)
    |> Enum.map(fn {_source, prediction} ->
      with {:ok, headsign} <-
             Content.Utilities.headsign_for_prediction(
               prediction.route_id,
               prediction.direction_id,
               prediction.destination_stop_id
             ),
           {:ok, destination} <- PaEss.Utilities.headsign_to_terminal_station(headsign) do
        %Content.Audio.Passthrough{
          destination: destination,
          trip_id: prediction.trip_id,
          route_id: prediction.route_id
        }
      else
        _ ->
          Logger.info("no_passthrough_audio_for_prediction prediction=#{inspect(prediction)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil(&1))
    |> Enum.at(0)
  end

  def get_passthrough_train_audio(_multi_source_sign) do
    nil
  end

  @spec get_source_list_predictions([Signs.Utilities.SourceConfig.source()], module()) :: [
          Predictions.Prediction.t()
        ]
  defp get_source_list_predictions(source_list, prediction_engine) do
    Enum.flat_map(source_list, fn source ->
      source.stop_id
      |> prediction_engine.for_stop(source.direction_id)
      |> Enum.filter(&(source.routes == nil or &1.route_id in source.routes))
      |> Enum.map(&{source, &1})
    end)
  end

  @spec stopped_train?(Predictions.Prediction.t()) :: boolean()
  defp stopped_train?(%{
         seconds_until_arrival: arrival_seconds,
         seconds_until_departure: departure_seconds
       })
       when arrival_seconds >= Content.Utilities.max_time_seconds() or
              departure_seconds >= Content.Utilities.max_time_seconds() do
    false
  end

  defp stopped_train?(prediction) do
    status = prediction.boarding_status
    status && String.starts_with?(status, "Stopped") && status != "Stopped at station"
  end

  @spec red_line_stops_away?(Predictions.Prediction.t()) :: boolean()
  defp red_line_stops_away?(prediction) do
    prediction.route_id == "Red" and
      (prediction.seconds_until_arrival || prediction.seconds_until_departure) > 60 * 8 and
      prediction.stops_away > 0
  end

  defp allowed_multi_berth_platform?(
         %SourceConfig{multi_berth?: true} = s1,
         %SourceConfig{multi_berth?: true} = s2
       )
       when s1 != s2 do
    true
  end

  defp allowed_multi_berth_platform?(_, _) do
    false
  end

  @spec sort_messages_by_stops_away([{SourceConfig.source() | nil, Content.Message.t()}]) :: [
          {SourceConfig.source() | nil, Content.Message.t()}
        ]
  defp sort_messages_by_stops_away([
         {s1, %Content.Message.StopsAway{stops_away: stops_away1} = m1},
         {s2, %Content.Message.StopsAway{stops_away: stops_away2} = m2}
       ])
       when stops_away2 < stops_away1 do
    [{s2, m2}, {s1, m1}]
  end

  defp sort_messages_by_stops_away(msgs) do
    msgs
  end
end
