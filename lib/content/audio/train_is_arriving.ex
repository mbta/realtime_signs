defmodule Content.Audio.TrainIsArriving do
  @moduledoc """
  The next train to [destination] is now arriving.
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:destination]
  defstruct @enforce_keys ++ [:trip_id, :platform, :route_id, crowding_description: nil]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          platform: Content.platform() | nil,
          route_id: String.t() | nil,
          crowding_description: {atom(), atom()} | nil
        }

  defimpl Content.Audio do
    def to_params(
          %Content.Audio.TrainIsArriving{crowding_description: crowding_description} = audio
        ) do
      case {dest_param(audio), crowding_description} do
        {nil, _} ->
          case Utilities.ad_hoc_trip_description(audio.destination, audio.route_id) do
            {:ok, trip_description} ->
              text = "Attention passengers: The next #{trip_description} is now arriving."
              {:ad_hoc, {text, :audio_visual}}

            {:error, :unknown} ->
              Logger.error("TrainIsArriving.to_params unknown params for #{inspect(audio)}")
              nil
          end

        {var, _} ->
          Utilities.take_message([var], :audio_visual)
      end
    end

    @spec dest_param(Content.Audio.TrainIsArriving.t()) :: String.t() | nil
    defp dest_param(%{destination: :alewife, platform: :ashmont}), do: "32105"
    defp dest_param(%{destination: :alewife, platform: :braintree}), do: "32106"
    defp dest_param(%{destination: :alewife, platform: nil}), do: "32104"
    defp dest_param(%{destination: :ashmont, route_id: "Mattapan"}), do: "90129"
    defp dest_param(%{destination: :ashmont, route_id: "Red"}), do: "32107"
    defp dest_param(%{destination: :braintree}), do: "32108"
    defp dest_param(%{destination: :mattapan}), do: "90128"
    defp dest_param(%{destination: :bowdoin}), do: "32101"
    defp dest_param(%{destination: :wonderland}), do: "32100"
    defp dest_param(%{destination: :forest_hills}), do: "32103"
    defp dest_param(%{destination: :oak_grove}), do: "32102"
    defp dest_param(%{destination: :lechmere}), do: "90016"
    defp dest_param(%{destination: :union_square}), do: "90019"
    defp dest_param(%{destination: :north_station}), do: "90017"
    defp dest_param(%{destination: :government_center}), do: "90015"
    defp dest_param(%{destination: :park_street}), do: "90014"
    defp dest_param(%{destination: :kenmore}), do: "90013"
    defp dest_param(%{destination: :boston_college}), do: "90005"
    defp dest_param(%{destination: :cleveland_circle}), do: "90007"
    defp dest_param(%{destination: :reservoir}), do: "90009"
    defp dest_param(%{destination: :riverside}), do: "90008"
    defp dest_param(%{destination: :heath_street}), do: "90011"
    defp dest_param(%{destination: :medford_tufts}), do: "853"
    defp dest_param(_), do: nil
  end
end
