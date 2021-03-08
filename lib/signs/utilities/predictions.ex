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
    |> Enum.sort_by(fn {source, prediction} ->
      {if source.terminal? do
         0
       else
         case prediction.stops_away do
           0 -> 0
           _ -> 1
         end
       end, prediction.seconds_until_departure, prediction.seconds_until_arrival}
    end)
    |> Enum.take(2)
    |> Enum.map(fn {source, prediction} ->
      cond do
        stopped_train?(prediction) and prediction.route_id == "Orange" and
            stations_away_experiment?() ->
          {source, Content.Message.StoppedAtStation.from_prediction(prediction)}

        stopped_train?(prediction) ->
          {source, Content.Message.StoppedTrain.from_prediction(prediction)}

        source.terminal? ->
          {source, Content.Message.Predictions.terminal(prediction)}

        true ->
          {source, Content.Message.Predictions.non_terminal(prediction)}
      end
    end)
    |> Enum.reject(fn {_source, message} -> is_nil(message) end)
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

  @spec get_passthrough_train_audio(Signs.Realtime.t()) :: [Content.Audio.t()]
  def get_passthrough_train_audio(%Signs.Realtime{source_config: {single_source}} = sign) do
    single_source |> get_source_list_passthrough_audio(sign.prediction_engine) |> List.wrap()
  end

  def get_passthrough_train_audio(
        %Signs.Realtime{source_config: {top_line_sources, bottom_line_sources}} = sign
      ) do
    (top_line_sources
     |> get_source_list_passthrough_audio(sign.prediction_engine)
     |> List.wrap()) ++
      (bottom_line_sources
       |> get_source_list_passthrough_audio(sign.prediction_engine)
       |> List.wrap())
  end

  @spec get_source_list_passthrough_audio([Signs.Utilities.SourceConfig.source()], module()) ::
          Content.Audio.t() | nil
  defp get_source_list_passthrough_audio(source_list, prediction_engine) do
    source_list
    |> get_source_list_predictions(prediction_engine)
    |> Enum.filter(fn {_source, prediction} ->
      prediction.seconds_until_passthrough && prediction.seconds_until_passthrough <= 60
    end)
    |> Enum.sort_by(fn {_source, prediction} -> prediction.seconds_until_passthrough end)
    |> Enum.map(fn {_source, prediction} ->
      route_id = prediction.route_id

      case Content.Utilities.destination_for_prediction(
             route_id,
             prediction.direction_id,
             prediction.destination_stop_id
           ) do
        {:ok, :southbound} when route_id == "Red" ->
          %Content.Audio.Passthrough{
            destination: :ashmont,
            trip_id: prediction.trip_id,
            route_id: prediction.route_id
          }

        {:ok, destination} ->
          %Content.Audio.Passthrough{
            destination: destination,
            trip_id: prediction.trip_id,
            route_id: prediction.route_id
          }

        _ ->
          Logger.info("no_passthrough_audio_for_prediction prediction=#{inspect(prediction)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil(&1))
    |> Enum.at(0)
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
    !is_nil(status) and String.starts_with?(status, "Stopped") and status != "Stopped at station"
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

  defp stations_away_experiment? do
    Application.get_env(:realtime_signs, :stations_away_experiment?, false)
  end
end
