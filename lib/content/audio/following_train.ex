defmodule Content.Audio.FollowingTrain do
  @moduledoc """
  The following train to [destination] arrives in [n] minutes.
  """

  @enforce_keys [:destination, :verb, :minutes]
  defstruct @enforce_keys

  @type verb :: :arrives | :departs

  @type t :: %__MODULE__{
          destination: PaEss.terminal_station(),
          verb: verb(),
          minutes: integer()
        }

  require Logger

  @spec from_predictions_message(
          Content.Message.Predictions.t(),
          Signs.Utilities.SourceConfig.source()
        ) :: Content.Audio.FollowingTrain.t() | nil
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: headsign}, %{
        terminal?: terminal
      })
      when is_integer(n) do
    case PaEss.Utilities.headsign_to_terminal_station(headsign) do
      {:ok, headsign_atom} ->
        %__MODULE__{
          destination: headsign_atom,
          minutes: n,
          verb: arrives_or_departs(terminal)
        }

      {:error, :unknown} ->
        Logger.warn(
          "Content.Audio.FollowingTrain.from_predictions_message: unknown headsign: #{headsign}"
        )

        nil
    end
  end

  def from_predictions_message(msg, _src) do
    Logger.error("message_to_audio_error Audio.FollowingTrain #{inspect(msg)}")
    nil
  end

  @spec arrives_or_departs(boolean) :: :arrives | :departs
  defp arrives_or_departs(true), do: :departs
  defp arrives_or_departs(false), do: :arrives

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(%{minutes: 1} = audio) do
      {"159", [Utilities.destination_var(audio.destination), verb_var(audio)], :audio}
    end

    def to_params(audio) do
      {"160", [Utilities.destination_var(audio.destination), verb_var(audio), minutes_var(audio)],
       :audio}
    end

    defp verb_var(%{verb: :arrives}), do: "503"
    defp verb_var(%{verb: :departs}), do: "502"

    defp minutes_var(%{minutes: minutes}) do
      Utilities.countdown_minutes_var(minutes)
    end
  end
end
