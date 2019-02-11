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
  alias Signs.Utilities.SourceConfig

  @spec from_predictions_message(Content.Message.t(), SourceConfig.source()) :: t() | nil
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: headsign}, %{
        terminal?: true
      })
      when is_integer(n) do
    case PaEss.Utilities.headsign_to_terminal_station(headsign) do
      {:ok, headsign_atom} ->
        %__MODULE__{
          destination: headsign_atom,
          minutes: n,
          verb: :departs
        }

      {:error, :unknown} ->
        Logger.warn(
          "Content.Audio.FollowingTrain.from_predictions_message: unknown headsign: #{headsign}"
        )

        nil
    end
  end

  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: headsign}, %{
        terminal?: false
      })
      when is_integer(n) do
    case PaEss.Utilities.headsign_to_terminal_station(headsign) do
      {:ok, headsign_atom} ->
        %__MODULE__{
          destination: headsign_atom,
          minutes: n,
          verb: :arrives
        }

      {:error, :unknown} ->
        Logger.warn(
          "Content.Audio.FollowingTrain.from_predictions_message: unknown headsign: #{headsign}"
        )

        nil
    end
  end

  def from_predictions_message(_, _src) do
    nil
  end

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
