defmodule Content.Audio.StoppedTrain do
  @moduledoc """
  The next train to [destination] is stopped [n] [stop/stops] away.
  """

  require Logger

  @enforce_keys [:destination, :stops_away]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.terminal_station(),
          stops_away: non_neg_integer()
        }

  @spec from_message(Content.Message.t()) :: t() | nil
  def from_message(%Content.Message.StoppedTrain{headsign: headsign, stops_away: stops_away}) do
    case PaEss.Utilities.headsign_to_terminal_station(headsign) do
      {:ok, terminal} ->
        %__MODULE__{destination: terminal, stops_away: stops_away}

      {:error, _} ->
        Logger.warn("unknown_headsign: #{headsign}")
        nil
    end
  end

  def from_message(_message) do
    nil
  end

  defimpl Content.Audio do
    def to_params(audio) do
      vars = [
        "501", # "the next"
        "507", # "train to"
        PaEss.Utilities.destination_var(audio.destination),
        "533", # "is"
        "641", # "stopped"
        number_var(audio.stops_away),
        stops_away_var(audio.stops_away),
      ]

      {PaEss.Utilities.take_message_id(vars), vars}
    end

    defp stops_away_var(1), do: "535"
    defp stops_away_var(_plural), do: "534"

    defp number_var(n) when n > 0 and n <= 100  do
      Integer.to_string(5000 + n)
    end
  end
end
