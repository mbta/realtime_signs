defmodule Content.Audio.Approaching do
  @moduledoc """
  The next train to [destination] is now approaching
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:destination]
  defstruct @enforce_keys ++ [:trip_id, :platform, :route_id, new_cars?: false]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          platform: Content.platform() | nil,
          route_id: String.t() | nil,
          new_cars?: boolean
        }

  defimpl Content.Audio do
    @attention_passengers "783"
    @now_approaching_new_ol_cars "785"

    def to_params(%Content.Audio.Approaching{new_cars?: false, route_id: route_id} = audio)
        when route_id in ["Mattapan", "Green-B", "Green-C", "Green-D", "Green-E"] do
      handle_unknown_destination(audio)
    end

    def to_params(%Content.Audio.Approaching{new_cars?: false} = audio) do
      case destination_var(audio.destination, audio.platform, audio.route_id) do
        nil ->
          case Utilities.ad_hoc_trip_description(audio.destination, audio.route_id) do
            {:ok, trip_description} ->
              text = "Attention passengers: The next #{trip_description} is now approaching."
              {:ad_hoc, {text, :audio_visual}}

            {:error, :unknown} ->
              handle_unknown_destination(audio)
          end

        var ->
          {:canned, {"103", [var], :audio_visual}}
      end
    end

    def to_params(%Content.Audio.Approaching{new_cars?: true} = audio) do
      case new_cars_destination_var(audio.destination) do
        nil ->
          to_params(%Content.Audio.Approaching{audio | new_cars?: false})

        var ->
          # can't use take_message/2 directly as the spaces cause problems
          vars = [@attention_passengers, var, @now_approaching_new_ol_cars]
          {:canned, {PaEss.Utilities.take_message_id(vars), vars, :audio_visual}}
      end
    end

    @spec handle_unknown_destination(Content.Audio.Approaching.t()) :: nil
    defp handle_unknown_destination(audio) do
      Logger.info(
        "unknown_approaching_audio: destination=#{audio.destination} route_id=#{audio.route_id} platform=#{
          audio.platform
        }"
      )

      nil
    end

    @spec destination_var(PaEss.destination(), Content.platform(), String.t()) :: String.t() | nil
    defp destination_var(:alewife, :ashmont, _route_id), do: "32125"
    defp destination_var(:alewife, :braintree, _route_id), do: "32126"
    defp destination_var(:alewife, nil, _route_id), do: "32124"
    defp destination_var(:ashmont, nil, "Red"), do: "32127"
    defp destination_var(:braintree, nil, _route_id), do: "32128"
    defp destination_var(:bowdoin, nil, _route_id), do: "32121"
    defp destination_var(:wonderland, nil, _route_id), do: "32120"
    defp destination_var(:forest_hills, nil, _route_id), do: "32123"
    defp destination_var(:oak_grove, nil, _route_id), do: "32122"
    defp destination_var(_destination, _platform, _route_id), do: nil

    @spec new_cars_destination_var(PaEss.destination()) :: String.t() | nil
    defp new_cars_destination_var(:oak_grove), do: "4022"
    defp new_cars_destination_var(:forest_hills), do: "4043"
    defp new_cars_destination_var(_destination), do: nil
  end
end
