defmodule Message.Predictions do
  @enforce_keys [:predictions, :terminal?, :special_sign]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          predictions: [Predictions.Prediction.t()],
          terminal?: boolean(),
          special_sign: :jfk_mezzanine | :bowdoin_eastbound | nil
        }

  defimpl Message do
    def to_single_line(%Message.Predictions{predictions: [top | _]} = message) do
      prediction_message(top, message.terminal?, message.special_sign)
    end

    def to_full_page(
          %Message.Predictions{predictions: [top | _], special_sign: :jfk_mezzanine} = message
        ) do
      {minutes, _} = PaEss.Utilities.prediction_minutes(top, message.terminal?)

      {prediction_message(top, message.terminal?, nil),
       %Content.Message.PlatformPredictionBottom{stop_id: top.stop_id, minutes: minutes}}
    end

    def to_multi_line(%Message.Predictions{predictions: [top]} = message) do
      {prediction_message(top, message.terminal?, message.special_sign), %Content.Message.Empty{}}
    end

    def to_multi_line(%Message.Predictions{predictions: [top, bottom]} = message) do
      {prediction_message(top, message.terminal?, message.special_sign),
       prediction_message(bottom, message.terminal?, message.special_sign)}
    end

    def to_audio(%Message.Predictions{} = message, multiple?) do
      same_destination? =
        Enum.map(message.predictions, &Content.Utilities.destination_for_prediction(&1))
        |> Enum.uniq()
        |> length() == 1

      Enum.take(message.predictions, if(multiple?, do: 1, else: 2))
      |> Enum.zip(if(same_destination?, do: [:next, :following], else: [:next, :next]))
      |> Enum.map(fn {prediction, next_or_following} ->
        %Content.Audio.Predictions{
          prediction: prediction,
          special_sign: message.special_sign,
          terminal?: message.terminal?,
          next_or_following: next_or_following
        }
      end)
    end

    defp prediction_message(prediction, terminal?, special_sign) do
      if PaEss.Utilities.prediction_stopped?(prediction, terminal?) do
        Content.Message.StoppedTrain.new(prediction, terminal?, special_sign)
      else
        Content.Message.Predictions.new(prediction, terminal?, special_sign)
      end
    end
  end
end
