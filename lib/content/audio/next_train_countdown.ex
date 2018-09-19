defmodule Content.Audio.NextTrainCountdown do
  @moduledoc """
  The next train to [destination] arrives in [n] minutes.
  """

  @enforce_keys [:destination, :verb, :minutes]
  defstruct @enforce_keys ++ [platform: nil]

  @type verb :: :arrives | :departs
  @type platform :: :ashmont | :braintree | nil

  @type t :: %__MODULE__{
          destination: PaEss.terminal_station(),
          verb: verb(),
          minutes: integer(),
          platform: :ashmont | :braintree | nil
        }

  require Logger
  alias Signs.Utilities.SourceConfig

  @spec from_predictions_message(Content.Message.t(), SourceConfig.source()) :: t() | nil
  def from_predictions_message(%Content.Message.Predictions{minutes: 1}, %{terminal?: false}) do
    nil
  end

  def from_predictions_message(
        %Content.Message.Predictions{minutes: n, headsign: headsign},
        src
      )
      when is_integer(n) do
    verb = if src.terminal?, do: :departs, else: :arrives

    case PaEss.Utilities.headsign_to_terminal_station(headsign) do
      {:ok, headsign_atom} ->
        %__MODULE__{destination: headsign_atom, minutes: n, verb: verb, platform: src.platform}

      {:error, :unknown} ->
        Logger.warn(
          "Content.Audio.NextTrainCountdown.from_predictions_message: unknown headsign: #{
            headsign
          }"
        )

        nil
    end
  end

  def from_predictions_message(_, _src) do
    nil
  end

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(%{platform: nil, minutes: 1} = audio) do
      {"141", [Utilities.destination_var(audio.destination), verb_var(audio)], :audio}
    end

    def to_params(%{platform: nil} = audio) do
      {"90", [Utilities.destination_var(audio.destination), verb_var(audio), minutes_var(audio)],
       :audio}
    end

    def to_params(%{minutes: 1} = audio) do
      {"142",
       [
         Utilities.destination_var(audio.destination),
         platform_var(audio),
         verb_var(audio)
       ], :audio}
    end

    def to_params(audio) do
      {"99",
       [
         Utilities.destination_var(audio.destination),
         platform_var(audio),
         verb_var(audio),
         minutes_var(audio)
       ], :audio}
    end

    defp platform_var(%{platform: :ashmont}), do: "4016"
    defp platform_var(%{platform: :braintree}), do: "4021"

    defp verb_var(%{verb: :arrives}), do: "503"
    defp verb_var(%{verb: :departs}), do: "502"

    defp minutes_var(%{minutes: minutes}) do
      Utilities.countdown_minutes_var(minutes)
    end
  end
end
