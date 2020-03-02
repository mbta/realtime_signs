defmodule Content.Audio.Passthrough do
  @moduledoc """
  The next [line] train to [destination] does not take customers
  """

  require Logger

  @enforce_keys [:destination]
  defstruct @enforce_keys ++ [:trip_id, :route_id]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          route_id: String.t() | nil
        }

  defimpl Content.Audio do
    def to_params(%Content.Audio.Passthrough{route_id: route_id} = audio)
        when route_id in ["Mattapan", "Green-B", "Green-C", "Green-D", "Green-E"] do
      handle_unknown_destination(audio)
    end

    def to_params(audio) do
      case destination_var(audio.destination, audio.route_id) do
        nil ->
          case PaEss.Utilities.ad_hoc_trip_description(audio.destination, audio.route_id) do
            {:ok, trip_description} ->
              text = "The next #{trip_description} does not take customers"
              {:ad_hoc, {text, :audio}}

            {:error, :unknown} ->
              handle_unknown_destination(audio)
          end

        var ->
          {:canned, {"103", [var], :audio_visual}}
      end
    end

    @spec handle_unknown_destination(Content.Audio.Passthrough.t()) :: nil
    defp handle_unknown_destination(audio) do
      Logger.info(
        "unknown_passthrough_audio: destination=#{audio.destination} route_id=#{audio.route_id}"
      )

      nil
    end

    @spec destination_var(PaEss.destination(), String.t()) :: String.t() | nil
    defp destination_var(:alewife, _route_id), do: "32114"
    defp destination_var(:ashmont, "Red"), do: "32117"
    defp destination_var(:braintree, _route_id), do: "32118"
    defp destination_var(:bowdoin, _route_id), do: "32111"
    defp destination_var(:wonderland, _route_id), do: "32110"
    defp destination_var(:forest_hills, _route_id), do: "32113"
    defp destination_var(:oak_grove, _route_id), do: "32112"
    defp destination_var(_destination, _route_id), do: nil
  end
end
