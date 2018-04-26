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

  require Logger

  @spec from_predictions_message(Content.Message.t()) :: t() | nil
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: "Ashmont"}) when is_integer(n) do
    %__MODULE__{destination: :ashmont, minutes: n}
  end
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: "Mattapan"}) when is_integer(n) do
    %__MODULE__{destination: :mattapan, minutes: n}
  end
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: headsign}) when is_integer(n) do
    Logger.warn("Content.Audio.NextTrainCountdown.from_predictions_message: unknown headsign: #{headsign}")
    nil
  end
  def from_predictions_message(_) do
    nil
  end

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
