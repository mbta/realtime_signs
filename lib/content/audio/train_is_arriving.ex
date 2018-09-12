defmodule Content.Audio.TrainIsArriving do
  @moduledoc """
  The next train to [destination] is now arriving.
  """

  require Logger

  @enforce_keys [:destination]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.terminal_station()
        }

  @spec from_predictions_message(Content.Message.t()) :: t() | nil
  def from_predictions_message(%Content.Message.Predictions{
        headsign: headsign,
        minutes: :arriving
      }) do
    case PaEss.Utilities.headsign_to_terminal_station(headsign) do
      {:ok, headsign_atom} ->
        %__MODULE__{destination: headsign_atom}

      {:error, :unknown} ->
        Logger.warn(
          "Content.Audio.TrainIsArriving.from_predictions_message: unknown headsign: #{headsign}"
        )

        nil
    end
  end

  def from_predictions_message(_) do
    nil
  end

  defimpl Content.Audio do
    def to_params(audio) do
      {message_id(audio), [], :audio_visual}
    end

    @spec message_id(Content.Audio.TrainIsArriving.t()) :: String.t()
    defp message_id(%{destination: :ashmont}), do: "90129"
    defp message_id(%{destination: :mattapan}), do: "90128"
    defp message_id(%{destination: :wonderland}), do: "90039"
    defp message_id(%{destination: :bowdoin}), do: "90040"
    defp message_id(%{destination: :forest_hills}), do: "90036"
    defp message_id(%{destination: :oak_grove}), do: "90038"
    defp message_id(%{destination: :braintree}), do: "90030"
    defp message_id(%{destination: :alewife}), do: "90029"
    defp message_id(%{destination: :boston_college}), do: "90005"
    defp message_id(%{destination: :cleveland_circle}), do: "90007"
    defp message_id(%{destination: :riverside}), do: "90008"
    defp message_id(%{destination: :heath_st}), do: "90011"
    defp message_id(%{destination: :reservoir}), do: "90009"
    defp message_id(%{destination: :lechmere}), do: "90016"
    defp message_id(%{destination: :north_station}), do: "90017"
    defp message_id(%{destination: :government_center}), do: "90015"
    defp message_id(%{destination: :park_st}), do: "90014"
    defp message_id(%{destination: :kenmore}), do: "90013"
  end
end
