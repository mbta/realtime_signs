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
