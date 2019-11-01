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
  def from_message(%Content.Message.StoppedTrain{headsign: headsign, stops_away: stops_away})
      when stops_away > 0 do
    case PaEss.Utilities.headsign_to_terminal_station(headsign) do
      {:ok, terminal} ->
        %__MODULE__{destination: terminal, stops_away: stops_away}

      {:error, _} ->
        Logger.warn("unknown_headsign: #{headsign}")
        nil
    end
  end

  def from_message(%Content.Message.StoppedTrain{stops_away: 0}) do
    nil
  end

  def from_message(message) do
    Logger.error("message_to_audio_error Audio.StoppedTrain #{inspect(message)}")
    nil
  end

  defimpl Content.Audio do
    @the_next "501"
    @train_to "507"
    @is "533"
    @stopped "641"

    def to_params(audio) do
      vars = [
        @the_next,
        @train_to,
        PaEss.Utilities.destination_var(audio.destination),
        @is,
        @stopped,
        number_var(audio.stops_away),
        stops_away_var(audio.stops_away)
      ]

      {:sign_content, {PaEss.Utilities.take_message_id(vars), vars, :audio}}
    end

    defp stops_away_var(1), do: "535"
    defp stops_away_var(_plural), do: "534"

    defp number_var(n) when n >= 0 and n <= 100 do
      Integer.to_string(5000 + n)
    end
  end
end
