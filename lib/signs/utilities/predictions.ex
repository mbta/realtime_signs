defmodule Signs.Utilities.Predictions do
  @moduledoc """
  Given a sign with a SourceConfig, fetches all relevant predictions and
  combines and sorts them, eventually returning the two relevent messages
  for the top and bottom lines.
  """

  require Logger
  require Content.Utilities
  alias Signs.Utilities.SourceConfig

  @spec get_messages(Signs.Realtime.t()) :: Signs.Realtime.sign_messages()
  def get_messages(
        %{
          source_config: {%{sources: top_line_sources}, %{sources: bottom_line_sources}},
          text_id: {station_code, zone}
        } = sign
      ) do
    {top, _} = get_predictions(sign.prediction_engine, top_line_sources, station_code, zone)
    {bottom, _} = get_predictions(sign.prediction_engine, bottom_line_sources, station_code, zone)

    {top, bottom}
  end

  def get_messages(
        %{source_config: %{sources: both_lines_sources}, text_id: {station_code, zone}} = sign
      ) do
    get_predictions(sign.prediction_engine, both_lines_sources, station_code, zone)
  end

  @spec get_predictions(module(), [SourceConfig.source()], String.t(), String.t()) ::
          Signs.Realtime.sign_messages()
  defp get_predictions(prediction_engine, source_list, station_code, zone) do
    source_list
    |> get_source_list_predictions(prediction_engine)
    |> Enum.filter(fn p ->
      p.seconds_until_departure
    end)
    |> Enum.sort_by(fn prediction ->
      {if terminal_prediction?(prediction, source_list) do
         0
       else
         case prediction.stops_away do
           0 -> 0
           _ -> 1
         end
       end, prediction.seconds_until_departure, prediction.seconds_until_arrival}
    end)
    |> Enum.map(fn prediction ->
      cond do
        stopped_train?(prediction) ->
          Content.Message.StoppedTrain.from_prediction(prediction)

        terminal_prediction?(prediction, source_list) ->
          Content.Message.Predictions.terminal(prediction)

        true ->
          Content.Message.Predictions.non_terminal(
            prediction,
            station_code,
            zone,
            platform(prediction, source_list)
          )
      end
    end)
    |> Enum.reject(&is_nil(&1))
    # Take next two predictions, but if the list has multiple destinations, prefer showing
    # distinct ones. This helps e.g. the red line trunk where people may need to know about
    # a particular branch.
    |> case do
      [msg1, msg2 | rest] ->
        case Enum.find([msg2 | rest], fn x -> x.destination != msg1.destination end) do
          nil -> [msg1, msg2]
          preferred -> [msg1, preferred]
        end

      messages ->
        messages
    end
    |> case do
      [] ->
        {Content.Message.Empty.new(), Content.Message.Empty.new()}

      [msg] ->
        {msg, Content.Message.Empty.new()}

      [
        %Content.Message.Predictions{minutes: :arriving} = p1,
        %Content.Message.Predictions{minutes: :arriving} = p2
      ] ->
        if allowed_multi_berth_platform?(source_list, p1, p2) do
          {p1, p2}
        else
          {p1, %{p2 | minutes: 1}}
        end

      [msg1, msg2] ->
        {msg1, msg2}
    end
  end

  @spec get_passthrough_train_audio(Signs.Realtime.t()) :: [Content.Audio.t()]
  def get_passthrough_train_audio(
        %Signs.Realtime{source_config: %{sources: single_source}} = sign
      ) do
    single_source |> get_source_list_passthrough_audio(sign.prediction_engine) |> List.wrap()
  end

  def get_passthrough_train_audio(
        %Signs.Realtime{
          source_config: {%{sources: top_line_sources}, %{sources: bottom_line_sources}}
        } = sign
      ) do
    (top_line_sources
     |> get_source_list_passthrough_audio(sign.prediction_engine)
     |> List.wrap()) ++
      (bottom_line_sources
       |> get_source_list_passthrough_audio(sign.prediction_engine)
       |> List.wrap())
  end

  @spec get_source_list_passthrough_audio([SourceConfig.source()], module()) ::
          Content.Audio.t() | nil
  defp get_source_list_passthrough_audio(source_list, prediction_engine) do
    source_list
    |> get_source_list_predictions(prediction_engine)
    |> Enum.filter(fn prediction ->
      prediction.seconds_until_passthrough && prediction.seconds_until_passthrough <= 60
    end)
    |> Enum.sort_by(fn prediction -> prediction.seconds_until_passthrough end)
    |> Enum.map(fn prediction ->
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

  @spec get_source_list_predictions([SourceConfig.source()], module()) :: [
          Predictions.Prediction.t()
        ]
  defp get_source_list_predictions(source_list, prediction_engine) do
    Enum.flat_map(source_list, fn source ->
      source.stop_id
      |> prediction_engine.for_stop(source.direction_id)
      |> Enum.filter(&(source.routes == nil or &1.route_id in source.routes))
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

  defp allowed_multi_berth_platform?(source_list, p1, p2) do
    allowed_multi_berth_platform?(
      SourceConfig.get_source_by_stop_and_direction(
        source_list,
        p1.stop_id,
        p1.direction_id
      ),
      SourceConfig.get_source_by_stop_and_direction(
        source_list,
        p2.stop_id,
        p2.direction_id
      )
    )
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

  defp terminal_prediction?(prediction, source_list) do
    source_list
    |> SourceConfig.get_source_by_stop_and_direction(
      prediction.stop_id,
      prediction.direction_id
    )
    |> case do
      nil -> false
      source -> source.terminal?
    end
  end

  defp platform(prediction, source_list) do
    source_list
    |> SourceConfig.get_source_by_stop_and_direction(
      prediction.stop_id,
      prediction.direction_id
    )
    |> case do
      nil -> nil
      source -> source.platform
    end
  end
end
