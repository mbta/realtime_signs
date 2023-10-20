defmodule Content.Audio.VehiclesToDestination do
  @moduledoc """
  Buses to Chelsea / S. Station arrive every [Number] to [Number] minutes
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:language, :destination, :headway_range]
  defstruct @enforce_keys ++ [:routes]

  @type t :: %__MODULE__{
          language: Content.Audio.language(),
          destination: PaEss.destination() | nil,
          headway_range: {non_neg_integer(), non_neg_integer()},
          routes: [String.t()] | nil
        }

  def from_headway_message(
        %Content.Message.Headways.Top{destination: nil, routes: routes},
        %Content.Message.Headways.Bottom{range: range}
      )
      when not is_nil(routes) do
    [
      %__MODULE__{
        language: :english,
        destination: nil,
        headway_range: range,
        routes: routes
      }
    ]
  end

  @spec from_headway_message(Content.Message.t(), Content.Message.t()) :: [t()]
  def from_headway_message(
        %Content.Message.Headways.Top{destination: destination},
        %Content.Message.Headways.Bottom{range: range}
      ) do
    create(:english, destination, range) ++ create(:spanish, destination, range)
  end

  def from_headway_message(top, bottom) do
    Logger.error(
      "message_to_audio_error Audio.VehiclesToDestination: #{inspect(top)}, #{inspect(bottom)}"
    )

    []
  end

  def from_paging_headway_message(%Content.Message.Headways.Paging{
        destination: destination,
        range: range
      }) do
    create(:english, destination, range)
  end

  @spec create(
          Content.Audio.language(),
          PaEss.destination() | nil,
          {non_neg_integer(), non_neg_integer()}
        ) :: [t()]

  defp create(:english, nil, range) do
    [
      %__MODULE__{
        language: :english,
        destination: nil,
        headway_range: range
      }
    ]
  end

  defp create(:spanish, nil, _range) do
    []
  end

  defp create(language, destination, headway_range) do
    if Utilities.valid_destination?(destination, language) do
      [
        %__MODULE__{
          language: language,
          destination: destination,
          headway_range: headway_range
        }
      ]
    else
      []
    end
  end

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(%Content.Audio.VehiclesToDestination{
          routes: routes,
          headway_range: {range_low, range_high}
        })
        when not is_nil(routes) do
      case routes do
        ["Mattapan"] ->
          {:ad_hoc, {"Mattapan trains every #{range_low} to #{range_high} minutes.", :audio}}

        [route] ->
          {:ad_hoc, {"#{route} line trains every #{range_low} to #{range_high} minutes.", :audio}}

        _ ->
          {:ad_hoc, {"Trains every #{range_low} to #{range_high} minutes.", :audio}}
      end
    end

    def to_params(%Content.Audio.VehiclesToDestination{
          language: :english,
          destination: nil,
          headway_range: {range_low, range_high}
        }) do
      {:ad_hoc, {"Trains every #{range_low} to #{range_high} minutes.", :audio}}
    end

    def to_params(
          %Content.Audio.VehiclesToDestination{
            headway_range: {lower_mins, higher_mins}
          } = audio
        )
        when is_integer(lower_mins) and is_integer(higher_mins) do
      case vars(audio) do
        nil ->
          Logger.warn("no_audio_for_headway_range #{inspect(audio)}")
          nil

        vars ->
          {:canned, {message_id(audio), vars, :audio}}
      end
    end

    def to_params(_audio), do: nil

    @spec message_id(Content.Audio.VehiclesToDestination.t()) :: String.t()
    defp message_id(%{language: :english, destination: :alewife}), do: "175"
    defp message_id(%{language: :english, destination: :ashmont}), do: "173"
    defp message_id(%{language: :english, destination: :braintree}), do: "174"
    defp message_id(%{language: :english, destination: :mattapan}), do: "180"
    defp message_id(%{language: :english, destination: :bowdoin}), do: "178"
    defp message_id(%{language: :english, destination: :wonderland}), do: "179"
    defp message_id(%{language: :english, destination: :forest_hills}), do: "176"
    defp message_id(%{language: :english, destination: :oak_grove}), do: "177"
    defp message_id(%{language: :english, destination: :lechmere}), do: "170"
    defp message_id(%{language: :english, destination: :union_square}), do: "194"
    defp message_id(%{language: :english, destination: :north_station}), do: "169"
    defp message_id(%{language: :english, destination: :government_center}), do: "167"
    defp message_id(%{language: :english, destination: :park_street}), do: "168"
    defp message_id(%{language: :english, destination: :kenmore}), do: "166"
    defp message_id(%{language: :english, destination: :boston_college}), do: "161"
    defp message_id(%{language: :english, destination: :cleveland_circle}), do: "162"
    defp message_id(%{language: :english, destination: :reservoir}), do: "165"
    defp message_id(%{language: :english, destination: :riverside}), do: "163"
    defp message_id(%{language: :english, destination: :heath_street}), do: "164"
    defp message_id(%{language: :english, destination: :medford_tufts}), do: "196"
    defp message_id(%{language: :english, destination: :northbound}), do: "183"
    defp message_id(%{language: :english, destination: :southbound}), do: "184"
    defp message_id(%{language: :english, destination: :eastbound}), do: "181"
    defp message_id(%{language: :english, destination: :westbound}), do: "182"
    defp message_id(%{language: :english, destination: :inbound}), do: "197"
    defp message_id(%{language: :english, destination: :outbound}), do: "198"

    defp message_id(%{language: :english, destination: :chelsea}), do: "133"
    defp message_id(%{language: :english, destination: :south_station}), do: "134"
    defp message_id(%{language: :spanish, destination: :chelsea}), do: "150"
    defp message_id(%{language: :spanish, destination: :south_station}), do: "151"

    @spec vars(Content.Audio.VehiclesToDestination.t()) :: [String.t()] | nil
    defp vars(%{language: language, headway_range: headway_range}) do
      case headway_range do
        {lower_mins, higher_mins} when is_integer(lower_mins) and is_integer(higher_mins) ->
          if Utilities.valid_range?(lower_mins, language) and
               Utilities.valid_range?(higher_mins, language) do
            [
              Utilities.number_var(lower_mins, language),
              Utilities.number_var(higher_mins, language)
            ]
          else
            nil
          end

        _ ->
          nil
      end
    end
  end
end
