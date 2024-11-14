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
  defstruct @enforce_keys ++ [:prediction]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          stops_away: non_neg_integer(),
          prediction: Predictions.Prediction.t()
        }

  @spec from_prediction(Predictions.Prediction.t()) :: t() | nil
  def from_prediction(%{boarding_status: status} = prediction) when not is_nil(status) do
    stops_away = parse_stops_away(prediction.boarding_status)

    %__MODULE__{
      destination: Content.Utilities.destination_for_prediction(prediction),
      stops_away: stops_away,
      prediction: prediction
    }
  end

  defp parse_stops_away(str) do
    ~r/Stopped (?<stops_away>\d+) stops? away/
    |> Regex.named_captures(str)
    |> Map.fetch!("stops_away")
    |> String.to_integer()
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
