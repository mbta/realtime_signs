defmodule Content.Audio.TrainIsArriving do
  @moduledoc """
  The next train to [destination] is now arriving.
  """

  require Logger

  @enforce_keys [:destination]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
    destination: :ashmont | :mattapan
  }

  @spec from_predictions_message(Content.Message.t()) :: t() | nil
  def from_predictions_message(%Content.Message.Predictions{headsign: "Ashmont", minutes: :arriving}) do
    %__MODULE__{destination: :ashmont}
  end
  def from_predictions_message(%Content.Message.Predictions{headsign: "Mattapan", minutes: :arriving}) do
    %__MODULE__{destination: :mattapan}
  end
  def from_predictions_message(%Content.Message.Predictions{headsign: headsign, minutes: :arriving}) do
    Logger.warn("Content.Audio.TrainIsArriving.from_predictions_message: unknown headsign: #{headsign}")
    nil
  end
  def from_predictions_message(_) do
    nil
  end

  defimpl Content.Audio do
    def to_params(audio) do
      {message_id(audio), [], :audio_visual}
    end

    defp message_id(%{destination: :ashmont}), do: "90129"
    defp message_id(%{destination: :mattapan}), do: "90128"
  end
end
