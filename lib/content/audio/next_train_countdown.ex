defmodule Content.Audio.NextTrainCountdown do
  @moduledoc """
  The next train to [destination] arrives in [n] minutes.
  """

  @enforce_keys [:destination, :verb, :minutes]
  defstruct @enforce_keys ++ [platform: nil]

  @type verb :: :arrives | :departs
  @type platform :: :ashmont | :braintree | nil

  @type t :: %__MODULE__{
    destination: :ashmont | :mattapan | :wonderland | :bowdoin | :forest_hills | :oak_grove,
    verb: verb(),
    minutes: integer(),
    platform: :ashmont | :braintree | nil
  }

  require Logger

  @spec from_predictions_message(Content.Message.t(), verb(), platform()) :: t() | nil
  def from_predictions_message(%Content.Message.Predictions{minutes: 1}, _verb, _platform) do
    nil
  end
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: "Ashmont"}, verb, _platform) when is_integer(n) do
    %__MODULE__{destination: :ashmont, minutes: n, verb: verb}
  end
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: "Mattapan"}, verb, _platform) when is_integer(n) do
    %__MODULE__{destination: :mattapan, minutes: n, verb: verb}
  end
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: "Wonderland"}, verb, _platform) when is_integer(n) do
    %__MODULE__{destination: :wonderland, minutes: n, verb: verb}
  end
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: "Bowdoin"}, verb, _platform) when is_integer(n) do
    %__MODULE__{destination: :bowdoin, minutes: n, verb: verb}
  end
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: "Frst Hills"}, verb, _platform) when is_integer(n) do
    %__MODULE__{destination: :forest_hills, minutes: n, verb: verb}
  end
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: "Oak Grove"}, verb, _platform) when is_integer(n) do
    %__MODULE__{destination: :oak_grove, minutes: n, verb: verb}
  end
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: "Braintree"}, verb, _platform) when is_integer(n) do
    %__MODULE__{destination: :braintree, minutes: n, verb: verb}
  end
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: "Alewife"}, verb, platform) when is_integer(n) do
    %__MODULE__{destination: :alewife, minutes: n, verb: verb, platform: platform}
  end
  def from_predictions_message(%Content.Message.Predictions{minutes: n, headsign: headsign}, _verb, _platform) when is_integer(n) do
    Logger.warn("Content.Audio.NextTrainCountdown.from_predictions_message: unknown headsign: #{headsign}")
    nil
  end
  def from_predictions_message(_, _verb, _platform) do
    nil
  end

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(%{platform: nil} = audio) do
      {"90", [destination_var(audio), verb_var(audio), minutes_var(audio)], :audio}
    end
    def to_params(audio) do
      {"99", [destination_var(audio), platform_var(audio), verb_var(audio), minutes_var(audio)], :audio}
    end

    defp destination_var(%{destination: :ashmont}), do: "4016"
    defp destination_var(%{destination: :mattapan}), do: "4100"
    defp destination_var(%{destination: :bowdoin}), do: "4055"
    defp destination_var(%{destination: :wonderland}), do: "4044"
    defp destination_var(%{destination: :forest_hills}), do: "4043"
    defp destination_var(%{destination: :oak_grove}), do: "4022"
    defp destination_var(%{destination: :braintree}), do: "4021"
    defp destination_var(%{destination: :alewife}), do: "4000"

    defp platform_var(%{platform: :ashmont}), do: "4016"
    defp platform_var(%{platform: :braintree}), do: "4021"

    defp verb_var(%{verb: :arrives}), do: "503"
    defp verb_var(%{verb: :departs}), do: "502"

    defp minutes_var(%{minutes: minutes}) do
      Utilities.countdown_minutes_var(minutes)
    end
  end
end
