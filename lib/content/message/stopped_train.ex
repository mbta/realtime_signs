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

  @enforce_keys [:headsign, :stops_away]
  defstruct @enforce_keys ++ [track_number: nil]

  @type t :: %__MODULE__{
          headsign: String.t(),
          stops_away: non_neg_integer(),
          track_number: Content.Utilities.track_number() | nil
        }

  @spec from_prediction(Predictions.Prediction.t()) :: t()
  def from_prediction(%{boarding_status: status} = prediction) when not is_nil(status) do
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

    stops_away = parse_stops_away(prediction.boarding_status)

    track_number =
      if stops_away == 0 do
        Content.Utilities.stop_track_number(prediction.stop_id)
      else
        nil
      end

    %__MODULE__{
      headsign: headsign,
      stops_away: stops_away,
      track_number: track_number
    }
  end

  defp parse_stops_away("Stopped at station") do
    0
  end

  defp parse_stops_away(str) do
    ~r/Stopped (?<stops_away>\d+) stops? away/
    |> Regex.named_captures(str)
    |> Map.fetch!("stops_away")
    |> String.to_integer()
  end

  defimpl Content.Message do
    def to_string(%{headsign: headsign, stops_away: 0, track_number: nil}) do
      Content.Utilities.width_padded_string(headsign, "BRD", 18)
    end

    def to_string(%{headsign: headsign, stops_away: 0, track_number: track_number}) do
      [
        {Content.Utilities.width_padded_string(headsign, "BRD", 18), 3},
        {Content.Utilities.width_padded_string(headsign, "Trk #{track_number}", 18), 3}
      ]
    end

    def to_string(%{headsign: headsign, stops_away: n}) do
      stop_word = if n == 1, do: "stop", else: "stops"

      [
        {Content.Utilities.width_padded_string(headsign, "Stopped", 18), 6},
        {Content.Utilities.width_padded_string(headsign, "#{n} #{stop_word}", 18), 3},
        {Content.Utilities.width_padded_string(headsign, "away", 18), 3}
      ]
    end
  end
end
