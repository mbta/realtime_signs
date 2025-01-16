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

    defp prediction_message(prediction, terminal?, special_sign) do
      if PaEss.Utilities.prediction_stopped?(prediction, terminal?) do
        Content.Message.StoppedTrain.new(prediction, terminal?, special_sign)
      else
        Content.Message.Predictions.new(prediction, terminal?, special_sign)
      end
    end
  end
end
