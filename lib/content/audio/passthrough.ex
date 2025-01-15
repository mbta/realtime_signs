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
          {:ad_hoc, {tts_text(audio), :audio_visual}}

        var ->
          {:canned, {"103", [var], :audio_visual}}
      end
    end

    def to_tts(%Content.Audio.Passthrough{} = audio) do
      text = tts_text(audio)
      {text, PaEss.Utilities.paginate_text(text)}
    end

    def to_logs(%Content.Audio.Passthrough{trip_id: trip_id}) do
      # trip_id for debugging RTR/Contentrate differences
      [trip_id: trip_id]
    end

    defp tts_text(%Content.Audio.Passthrough{} = audio) do
      train = PaEss.Utilities.train_description(audio.destination, audio.route_id)
      "The next #{train} does not take customers. Please stand back from the yellow line."
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
    defp destination_var(:ashmont, "Red"), do: "891"
    defp destination_var(:braintree, _route_id), do: "891"
    defp destination_var(:bowdoin, _route_id), do: "32111"
    defp destination_var(:wonderland, _route_id), do: "32110"
    defp destination_var(:forest_hills, _route_id), do: "32113"
    defp destination_var(:oak_grove, _route_id), do: "32112"
    defp destination_var(_destination, _route_id), do: nil
  end
end
