defmodule Content.Audio.TrainIsArriving do
  @moduledoc """
  The next train to [destination] is now arriving.
  """

  require Logger
  alias Content.Message
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

  def from_message(%Message.Predictions{} = message, crowding_description) do
    [
      %__MODULE__{
        destination: message.destination,
        trip_id: message.prediction.trip_id,
        platform: Content.Utilities.stop_platform(message.prediction.stop_id),
        route_id: message.prediction.route_id,
        crowding_description: crowding_description
      }
    ]
  end

  defimpl Content.Audio do
    def to_params(
          %Content.Audio.TrainIsArriving{crowding_description: crowding_description} = audio
        ) do
      case {dest_param(audio), crowding_description} do
        {nil, _} ->
          {:ad_hoc, {tts_text(audio), :audio_visual}}

        {var, nil} ->
          Utilities.take_message([var], :audio_visual)

        {var, crowding_description} ->
          Utilities.take_message(
            [var, Content.Utilities.crowding_description_var(crowding_description)],
            :audio_visual
          )
      end
    end

    def to_tts(%Content.Audio.TrainIsArriving{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, audio.route_id, :visual)
      crowding = PaEss.Utilities.crowding_text(audio.crowding_description)
      pages = [{train, "now arriving", 6}] ++ PaEss.Utilities.paginate_text(crowding)
      {tts_text(audio), pages}
    end

    def to_logs(%Content.Audio.TrainIsArriving{}) do
      []
    end

    defp tts_text(%Content.Audio.TrainIsArriving{} = audio) do
      train = Utilities.train_description(audio.destination, audio.route_id)
      crowding = PaEss.Utilities.crowding_text(audio.crowding_description)
      "Attention passengers: The next #{train} is now arriving.#{crowding}"
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
