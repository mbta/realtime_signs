defmodule Content.Audio.NextTrainCountdown do
  @moduledoc """
  The next train to [destination] arrives in [n] minutes.
  """

  @enforce_keys [:destination, :minutes]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
    destination: :ashmont | :mattapan,
    minutes: integer()
  }

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(audio) do
      {"90", [destination_var(audio), arrives_in_var(), minutes_var(audio)], :audio}
    end

    defp destination_var(%{destination: :ashmont}), do: "4016"
    defp destination_var(%{destination: :mattapan}), do: "4100"

    defp arrives_in_var(), do: "503"

    defp minutes_var(%{minutes: minutes}) do
      Utilities.countdown_minutes_var(minutes)
    end
  end
end
