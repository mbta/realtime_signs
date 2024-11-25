defmodule Signs.Utilities.Predictions do
  @moduledoc """
  Given a sign with a SourceConfig, fetches all relevant predictions and
  combines and sorts them, eventually returning the two relevent messages
  for the top and bottom lines.
  """

  require Logger
  require Content.Utilities
  alias Signs.Utilities.SourceConfig

  @reverse_prediction_certainty 360
  @max_prediction_sec 60 * 60
  @reverse_prediction_cutoff_sec 20 * 60

  def prediction_message(predictions, config, sign) do
    case prediction_messages(predictions, config, sign) do
      nil -> nil
      {first, _} -> first
    end
  end

  @spec prediction_messages(
          [Predictions.Prediction.t()],
          SourceConfig.config(),
          Signs.Realtime.t()
        ) :: Signs.Realtime.sign_messages() | nil
  def prediction_messages(predictions, %{terminal?: terminal?}, sign) do
    predictions
    |> Enum.filter(fn p ->
      p.seconds_until_departure && p.schedule_relationship != :skipped
    end)
    |> Enum.sort_by(fn prediction ->
      {if terminal? do
         0
       else
         if prediction.stopped_at_predicted_stop?,
           do: 0,
           else: 1
       end, prediction.seconds_until_departure, prediction.seconds_until_arrival}
    end)
    |> filter_large_red_line_gaps()
    |> Enum.map(fn prediction ->
      if stopped_train?(prediction) do
        Content.Message.StoppedTrain.from_prediction(prediction)
      else
        special_sign =
          case sign do
            %{pa_ess_loc: "RJFK", text_zone: "m"} -> :jfk_mezzanine
            %{pa_ess_loc: "BBOW", text_zone: "e"} -> :bowdoin_eastbound
            _ -> nil
          end

        Content.Message.Predictions.new(prediction, terminal?, special_sign)
      end
    end)
    # Take next two predictions, but if the list has multiple destinations, prefer showing
    # distinct ones. This helps e.g. the red line trunk where people may need to know about
    # a particular branch.
    |> get_unique_destination_predictions(SourceConfig.single_route(sign.source_config))
    |> case do
      [] ->
        nil

      [msg] ->
        {msg, Content.Message.Empty.new()}

      [msg1, msg2] ->
        {msg1, msg2}
    end
  end

  @spec reverse_prediction?(Predictions.Prediction.t(), boolean()) :: boolean()
  def reverse_prediction?(%Predictions.Prediction{} = prediction, terminal?) do
    certainty =
      if terminal? || !prediction.seconds_until_arrival do
        prediction.departure_certainty
      else
        prediction.arrival_certainty
      end

    certainty == @reverse_prediction_certainty
  end

  defp get_unique_destination_predictions(predictions, "Green") do
    Enum.take(predictions, 2)
  end

  defp get_unique_destination_predictions(predictions, _) do
    case predictions do
      [msg1, msg2 | rest] ->
        case Enum.find([msg2 | rest], fn x -> x.destination != msg1.destination end) do
          nil -> [msg1, msg2]
          preferred -> [msg1, preferred]
        end

      messages ->
        messages
    end
  end

  @spec get_passthrough_train_audio(Signs.Realtime.predictions()) :: [Content.Audio.t()]
  def get_passthrough_train_audio({top_predictions, bottom_predictions}) do
    prediction_passthrough_audios(top_predictions) ++
      prediction_passthrough_audios(bottom_predictions)
  end

  def get_passthrough_train_audio(predictions) do
    prediction_passthrough_audios(predictions)
  end

  @spec prediction_passthrough_audios([Predictions.Prediction.t()]) :: [Content.Audio.t()]
  defp prediction_passthrough_audios(predictions) do
    predictions
    |> Enum.filter(fn prediction ->
      prediction.seconds_until_passthrough && prediction.seconds_until_passthrough <= 60
    end)
    |> Enum.sort_by(fn prediction -> prediction.seconds_until_passthrough end)
    |> Enum.flat_map(fn prediction ->
      destination =
        case Content.Utilities.destination_for_prediction(prediction) do
          :southbound -> :ashmont
          destination -> destination
        end

      [
        %Content.Audio.Passthrough{
          destination: destination,
          trip_id: prediction.trip_id,
          route_id: prediction.route_id
        }
      ]
    end)
    |> Enum.take(1)
  end

  defp approximate_time?(sec, certainty) do
    sec &&
      (sec > @max_prediction_sec ||
         (sec > @reverse_prediction_cutoff_sec && certainty == @reverse_prediction_certainty))
  end

  @spec stopped_train?(Predictions.Prediction.t()) :: boolean()
  defp stopped_train?(%{
         boarding_status: boarding_status,
         seconds_until_arrival: seconds_until_arrival,
         seconds_until_departure: seconds_until_departure,
         arrival_certainty: arrival_certainty,
         departure_certainty: departure_certainty
       }) do
    # Note: This performs a similar (but not identical) calculation to the one in the Message
    # code for determining whether a prediction will show an approximate time. Ideally they
    # should both call the same logic.
    approximate_arrival? = approximate_time?(seconds_until_arrival, arrival_certainty)
    approximate_departure? = approximate_time?(seconds_until_departure, departure_certainty)

    boarding_status && String.starts_with?(boarding_status, "Stopped") &&
      boarding_status != "Stopped at station" && !approximate_arrival? && !approximate_departure?
  end

  # This is a temporary fix for a situation where spotty train sheet data can
  # cause some predictions to not show up until right before they leave the
  # terminal. This makes it appear that the next train will be much later than
  # it is. At stations near Ashmont and Braintree, we're discarding any
  # predictions following a gap of more than 21 minutes from the previous one,
  # since this is a reasonable indicator of this problem.
  defp filter_large_red_line_gaps([first | _] = predictions)
       when first.stop_id in ~w(70105 Braintree-01 Braintree-02 70104 70102 70100 70094 70092 70090 70088 70098 70086 70096) do
    [%{seconds_until_departure: 0} | predictions]
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.take_while(fn [prev, current] ->
      current.seconds_until_departure - prev.seconds_until_departure < 21 * 60
    end)
    |> Enum.map(&List.last/1)
  end

  defp filter_large_red_line_gaps(predictions), do: predictions
end
