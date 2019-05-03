defmodule Content.Audio.Approaching do
  @moduledoc """
  The next train to [destination] is now approaching
  """

  require Logger

  @enforce_keys [:destination]
  defstruct @enforce_keys ++ [:trip_id, :platform, :route_id]

  @type t :: %__MODULE__{
          destination: PaEss.terminal_station(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          platform: Content.platform() | nil,
          route_id: String.t() | nil
        }

  defimpl Content.Audio do
    def to_params(audio) do
      case destination_var(audio.destination, audio.platform, audio.route_id) do
        nil ->
          Logger.info(
            "unknown_approaching_audio: destination=#{audio.destination} route_id=#{
              audio.route_id
            } platform=#{audio.platform}"
          )

          nil

        var ->
          {"103", [var], :audio_visual}
      end
    end

    @spec destination_var(PaEss.terminal_station(), Content.platform(), String.t()) ::
            String.t() | nil
    defp destination_var(:wonderland, nil, _route_id), do: "32120"
    defp destination_var(:bowdoin, nil, _route_id), do: "32121"
    defp destination_var(:oak_grove, nil, _route_id), do: "32122"
    defp destination_var(:forest_hills, nil, _route_id), do: "32123"
    defp destination_var(:alewife, nil, _route_id), do: "32124"
    defp destination_var(:alewife, :ashmont, _route_id), do: "32125"
    defp destination_var(:alewife, :braintree, _route_id), do: "32126"
    defp destination_var(:ashmont, nil, "Red"), do: "32127"
    defp destination_var(:braintree, nil, _route_id), do: "32128"
    defp destination_var(_destination, _platform, _route_id), do: nil
  end
end
