defmodule Content.Message.StoppedTrain do
  @moduledoc """
  A message for when a train is stopped in a segment. It paginates through:

  Ashmont   Stopped
  Ashmont   3 stops
  Ashmont   away

  If the number of stops is 1, then it's "1 stop", and if it's 0,
  then it's the normal Ashmont BRD.
  """

  @enforce_keys [:headsign, :stops_away]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          headsign: String.t(),
          stops_away: non_neg_integer()
        }

  defimpl Content.Message do
    def to_string(%{headsign: headsign, stops_away: 0}) do
      Content.Utilities.width_padded_string(headsign, "BRD", 18)
    end

    def to_string(%{headsign: headsign, stops_away: n}) do
      stop_word = if n == 1, do: "stop ", else: "stops"

      pages = [
        Content.Utilities.width_padded_string(headsign, "Stopped", 18),
        Content.Utilities.width_padded_string(headsign, "#{n} #{stop_word}", 18),
        Content.Utilities.width_padded_string(headsign, "away   ", 18)
      ]

      {pages, 5}
    end
  end
end
