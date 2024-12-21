defmodule Signs.Utilities.Predictions do
  @moduledoc """
  Given a sign with a SourceConfig, fetches all relevant predictions and
  combines and sorts them, eventually returning the two relevent messages
  for the top and bottom lines.
  """

  require Logger
  require Content.Utilities
  alias Signs.Utilities.SourceConfig

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
    |> case do
      [] ->
        nil

      [msg] ->
        {msg, Content.Message.Empty.new()}

      [msg1, msg2] ->
        {msg1, msg2}
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

  defp approximate_time?(sec, prediction_type) do
    sec &&
      (sec > @max_prediction_sec ||
         (sec > @reverse_prediction_cutoff_sec && prediction_type == :reverse))
  end

  @spec stopped_train?(Predictions.Prediction.t()) :: boolean()
  defp stopped_train?(%{
         boarding_status: boarding_status,
         seconds_until_arrival: seconds_until_arrival,
         seconds_until_departure: seconds_until_departure,
         type: type
       }) do
    # Note: This performs a similar (but not identical) calculation to the one in the Message
    # code for determining whether a prediction will show an approximate time. Ideally they
    # should both call the same logic.
    approximate_arrival? = approximate_time?(seconds_until_arrival, type)
    approximate_departure? = approximate_time?(seconds_until_departure, type)

    boarding_status && String.starts_with?(boarding_status, "Stopped") &&
      boarding_status != "Stopped at station" && !approximate_arrival? && !approximate_departure?
  end
end
