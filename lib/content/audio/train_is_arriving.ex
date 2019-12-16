defmodule Content.Audio.TrainIsArriving do
  @moduledoc """
  The next train to [destination] is now arriving.
  """

  require Logger

  @enforce_keys [:destination]
  defstruct @enforce_keys ++ [:trip_id, :platform, :route_id]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          platform: Content.platform() | nil,
          route_id: String.t() | nil
        }

  defimpl Content.Audio do
    @priority 1

    def to_params(%{destination: :southbound, route_id: "Red"}) do
      text = "Attention passengers: The next southbound Red Line train is now arriving."
      {:ad_hoc, {text, :audio_visual, @priority}}
    end

    def to_params(audio) do
      case audio_params(audio) do
        {message_id, vars} ->
          {:canned, {message_id, vars, :audio_visual, @priority}}

        nil ->
          Logger.error("TrainIsArriving.to_params unknown params for #{inspect(audio)}")
          nil
      end
    end

    @spec audio_params(Content.Audio.TrainIsArriving.t()) :: {String.t(), [String.t()]} | nil
    defp audio_params(%{destination: :alewife, platform: :ashmont}), do: {"103", ["32105"]}
    defp audio_params(%{destination: :alewife, platform: :braintree}), do: {"103", ["32106"]}
    defp audio_params(%{destination: :alewife, platform: nil}), do: {"103", ["32104"]}
    defp audio_params(%{destination: :ashmont, route_id: "Mattapan"}), do: {"90129", []}
    defp audio_params(%{destination: :ashmont, route_id: "Red"}), do: {"103", ["32107"]}
    defp audio_params(%{destination: :braintree}), do: {"103", ["32108"]}
    defp audio_params(%{destination: :mattapan}), do: {"90128", []}
    defp audio_params(%{destination: :bowdoin}), do: {"103", ["32101"]}
    defp audio_params(%{destination: :wonderland}), do: {"103", ["32100"]}
    defp audio_params(%{destination: :forest_hills}), do: {"103", ["32103"]}
    defp audio_params(%{destination: :oak_grove}), do: {"103", ["32102"]}
    defp audio_params(%{destination: :lechmere}), do: {"90016", []}
    defp audio_params(%{destination: :north_station}), do: {"90017", []}
    defp audio_params(%{destination: :government_center}), do: {"90015", []}
    defp audio_params(%{destination: :park_street}), do: {"90014", []}
    defp audio_params(%{destination: :kenmore}), do: {"90013", []}
    defp audio_params(%{destination: :boston_college}), do: {"90005", []}
    defp audio_params(%{destination: :cleveland_circle}), do: {"90007", []}
    defp audio_params(%{destination: :reservoir}), do: {"90009", []}
    defp audio_params(%{destination: :riverside}), do: {"90008", []}
    defp audio_params(%{destination: :heath_street}), do: {"90011", []}
    defp audio_params(_), do: nil
  end
end
