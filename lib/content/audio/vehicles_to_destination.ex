defmodule Content.Audio.VehiclesToDestination do
  @moduledoc """
  Buses to Chelsea / S. Station arrive every [Number] to [Number] minutes
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:destination, :headway_range]
  defstruct @enforce_keys ++ [:routes]

  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          headway_range: {non_neg_integer(), non_neg_integer()},
          routes: [String.t()] | nil
        }

  def from_headway_message(
        %Content.Message.Headways.Top{destination: destination, routes: routes},
        %Content.Message.Headways.Bottom{range: range}
      ) do
    [
      %__MODULE__{
        destination: destination,
        headway_range: range,
        routes: routes
      }
    ]
  end

  def from_paging_headway_message(%Content.Message.Headways.Paging{
        destination: destination,
        range: range
      }) do
    [
      %__MODULE__{
        destination: destination,
        headway_range: range
      }
    ]
  end

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(
          %Content.Audio.VehiclesToDestination{
            headway_range: {range_low, range_high},
            routes: routes
          } = audio
        ) do
      low_var = Utilities.number_var(range_low, :english)
      high_var = Utilities.number_var(range_high, :english)

      if low_var && high_var && !routes do
        {:canned, {message_id(audio), [low_var, high_var], :audio}}
      else
        {:ad_hoc, {tts_text(audio), :audio}}
      end
    end

    def to_tts(%Content.Audio.VehiclesToDestination{} = audio) do
      {tts_text(audio), nil}
    end

    defp tts_text(%Content.Audio.VehiclesToDestination{
           headway_range: {range_low, range_high},
           destination: destination,
           routes: routes
         }) do
      trains =
        case {destination, routes} do
          {_, [route]} ->
            "#{route} line trains"

          {_, routes} when is_list(routes) ->
            "Trains"

          {destination, _} ->
            {:ok, destination_text} = PaEss.Utilities.destination_to_ad_hoc_string(destination)
            "#{destination_text} trains"
        end

      "#{trains} every #{range_low} to #{range_high} minutes."
    end

    @spec message_id(Content.Audio.VehiclesToDestination.t()) :: String.t()
    defp message_id(%{destination: :alewife}), do: "175"
    defp message_id(%{destination: :ashmont}), do: "173"
    defp message_id(%{destination: :braintree}), do: "174"
    defp message_id(%{destination: :mattapan}), do: "180"
    defp message_id(%{destination: :bowdoin}), do: "178"
    defp message_id(%{destination: :wonderland}), do: "179"
    defp message_id(%{destination: :forest_hills}), do: "176"
    defp message_id(%{destination: :oak_grove}), do: "177"
    defp message_id(%{destination: :lechmere}), do: "170"
    defp message_id(%{destination: :union_square}), do: "194"
    defp message_id(%{destination: :north_station}), do: "169"
    defp message_id(%{destination: :government_center}), do: "167"
    defp message_id(%{destination: :park_street}), do: "168"
    defp message_id(%{destination: :kenmore}), do: "166"
    defp message_id(%{destination: :boston_college}), do: "161"
    defp message_id(%{destination: :cleveland_circle}), do: "162"
    defp message_id(%{destination: :reservoir}), do: "165"
    defp message_id(%{destination: :riverside}), do: "163"
    defp message_id(%{destination: :heath_street}), do: "164"
    defp message_id(%{destination: :medford_tufts}), do: "196"
    defp message_id(%{destination: :northbound}), do: "183"
    defp message_id(%{destination: :southbound}), do: "184"
    defp message_id(%{destination: :eastbound}), do: "181"
    defp message_id(%{destination: :westbound}), do: "182"
    defp message_id(%{destination: :inbound}), do: "197"
    defp message_id(%{destination: :outbound}), do: "198"
    defp message_id(%{destination: :chelsea}), do: "133"
    defp message_id(%{destination: :south_station}), do: "134"
  end
end
