defmodule Content.Audio.StoppedTrain do
  @moduledoc """
  The next train to [destination] is stopped [n] [stop/stops] away.
  """

  require Logger

  @enforce_keys [:destination, :stops_away]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          stops_away: non_neg_integer()
        }

  @spec from_message(Content.Message.t()) :: t() | nil
  def from_message(%Content.Message.StoppedTrain{destination: destination, stops_away: stops_away})
      when stops_away > 0 do
    %__MODULE__{destination: destination, stops_away: stops_away}
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

    def to_params(%{destination: :southbound, stops_away: stops_away}) do
      stop_or_stops = if stops_away == 1, do: "stop", else: "stops"
      text = "The next southbound train is stopped #{stops_away} #{stop_or_stops} away"
      {:ad_hoc, {text, :audio}}
    end

    def to_params(audio) do
      case PaEss.Utilities.destination_var(audio.destination) do
        {:ok, dest_var} ->
          vars = [
            @the_next,
            @train_to,
            dest_var,
            @is,
            @stopped,
            number_var(audio.stops_away),
            stops_away_var(audio.stops_away)
          ]

          PaEss.Utilities.take_message(vars, :audio)

        {:error, :unknown} ->
          Logger.error(
            "StoppedTrain.to_params unknown destination: #{inspect(audio.destination)}"
          )

          nil
      end
    end

    defp stops_away_var(1), do: "535"
    defp stops_away_var(_plural), do: "534"

    defp number_var(n) when n >= 0 and n <= 100 do
      Integer.to_string(5000 + n)
    end
  end
end
