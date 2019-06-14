defmodule Content.Message.StopsAway do
  @enforce_keys [:headsign, :stops_away]

  defstruct @enforce_keys

  require Logger

  @type t :: %__MODULE__{
          headsign: String.t(),
          stops_away: integer()
        }

  @spec from_prediction(Predictions.Prediction.t()) :: t()
  def from_prediction(prediction) do
    headsign =
      case Content.Utilities.headsign_for_prediction(
             prediction.route_id,
             prediction.direction_id,
             prediction.destination_stop_id
           ) do
        {:ok, dest} ->
          dest

        {:error, _} ->
          Logger.warn("Could not find headsign for prediction #{inspect(prediction)}")
          ""
      end

    %__MODULE__{
      headsign: headsign,
      stops_away: prediction.stops_away
    }
  end

  defimpl Content.Message do
    def to_string(%Content.Message.StopsAway{headsign: headsign, stops_away: n}) do
      stop_word = if n == 1, do: "stop", else: "stops"

      [
        {Content.Utilities.width_padded_string(headsign, "away", 18), 3},
        {Content.Utilities.width_padded_string(headsign, "#{n} #{stop_word}", 18), 3}
      ]
    end
  end
end
