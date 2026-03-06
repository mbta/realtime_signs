defmodule Content.Audio.VehiclesToDestination do
  @moduledoc """
  Buses to Chelsea / S. Station arrive every [Number] to [Number] minutes
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:destination, :headway_range]
  defstruct @enforce_keys ++ [:route]

  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          headway_range: {non_neg_integer(), non_neg_integer()},
          route: String.t() | nil
        }

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(
          %Content.Audio.VehiclesToDestination{
            headway_range: {range_low, range_high},
            destination: destination
          } = audio
        ) do
      low_var = Utilities.number_var(range_low, :english)
      high_var = Utilities.number_var(range_high, :english)

      if low_var && high_var && destination do
        {:canned, {message_id(audio), [low_var, high_var], :audio}}
      else
        {:ad_hoc, {tts_text(audio), :audio}}
      end
    end

    def to_tts(%Content.Audio.VehiclesToDestination{} = audio, _max_text_length) do
      {tts_text(audio), nil}
    end

    def to_logs(%Content.Audio.VehiclesToDestination{}) do
      []
    end

    defp tts_text(%Content.Audio.VehiclesToDestination{
           headway_range: {range_low, range_high},
           destination: destination,
           route: route
         }) do
      trains =
        case {destination, route} do
          {nil, nil} ->
            "Trains"

          {nil, route} ->
            "#{route} line trains"

          {destination, _} ->
            destination_text = PaEss.Utilities.destination_to_ad_hoc_string(destination)
            "#{destination_text} trains"
        end

      "#{trains} every #{range_low} to #{range_high} minutes."
    end

    @spec message_id(Content.Audio.VehiclesToDestination.t()) :: String.t()
    defp message_id(%{destination: "place-alfcl"}), do: "175"
    defp message_id(%{destination: "place-asmnl"}), do: "173"
    defp message_id(%{destination: "place-brntn"}), do: "174"
    defp message_id(%{destination: "place-matt"}), do: "180"
    defp message_id(%{destination: "place-bomnl"}), do: "178"
    defp message_id(%{destination: "place-wondl"}), do: "179"
    defp message_id(%{destination: "place-forhl"}), do: "176"
    defp message_id(%{destination: "place-ogmnl"}), do: "177"
    defp message_id(%{destination: "place-lech"}), do: "170"
    defp message_id(%{destination: "place-unsqu"}), do: "194"
    defp message_id(%{destination: "place-north"}), do: "169"
    defp message_id(%{destination: "place-gover"}), do: "167"
    defp message_id(%{destination: "place-pktrm"}), do: "168"
    defp message_id(%{destination: "place-kencl"}), do: "166"
    defp message_id(%{destination: "place-lake"}), do: "161"
    defp message_id(%{destination: "place-clmnl"}), do: "162"
    defp message_id(%{destination: "place-rsmnl"}), do: "165"
    defp message_id(%{destination: "place-river"}), do: "163"
    defp message_id(%{destination: "place-hsmnl"}), do: "164"
    defp message_id(%{destination: "place-mdftf"}), do: "196"
    defp message_id(%{destination: :northbound}), do: "183"
    defp message_id(%{destination: :southbound}), do: "184"
    defp message_id(%{destination: :eastbound}), do: "181"
    defp message_id(%{destination: :westbound}), do: "182"
    defp message_id(%{destination: :inbound}), do: "197"
    defp message_id(%{destination: :outbound}), do: "198"
    defp message_id(%{destination: "place-chels"}), do: "133"
    defp message_id(%{destination: "place-sstat"}), do: "134"
  end
end
