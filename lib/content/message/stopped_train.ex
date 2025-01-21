defmodule Content.Message.StoppedTrain do
  @moduledoc """
  A message for when a train is stopped in a segment. It paginates through:

  Ashmont   Stopped
  Ashmont   3 stops
  Ashmont   away

  If the number of stops is 1, then it's "1 stop", and if it's 0,
  then it's the normal Ashmont BRD.
  """

  require Logger

  @enforce_keys [:destination, :stops_away]
  defstruct @enforce_keys ++ [:prediction, :terminal?, :special_sign]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          stops_away: non_neg_integer(),
          prediction: Predictions.Prediction.t(),
          special_sign: :jfk_mezzanine | :bowdoin_eastbound | nil,
          terminal?: boolean()
        }

  @spec new(Predictions.Prediction.t(), boolean(), :jfk_mezzanine | :bowdoin_eastbound | nil) ::
          t()
  def new(prediction, terminal?, special_sign) do
    %__MODULE__{
      destination: Content.Utilities.destination_for_prediction(prediction),
      stops_away: PaEss.Utilities.prediction_stops_away(prediction),
      prediction: prediction,
      terminal?: terminal?,
      special_sign: special_sign
    }
  end

  defimpl Content.Message do
    def to_string(%{destination: destination, stops_away: n}) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)

      stop_word = if n == 1, do: "stop", else: "stops"

      [
        {Content.Utilities.width_padded_string(headsign, "Stopped", 18), 6},
        {Content.Utilities.width_padded_string(headsign, "#{n} #{stop_word}", 18), 6},
        {Content.Utilities.width_padded_string(headsign, "away", 18), 6}
      ]
    end
  end
end
