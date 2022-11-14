defmodule Content.Audio.VehiclesToDestination do
  @moduledoc """
  Buses to Chelsea / S. Station arrive every [Number] to [Number] minutes
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:language, :destination, :headway_range]
  defstruct @enforce_keys ++ [:previous_departure_mins]

  @type t :: %__MODULE__{
          language: Content.Audio.language(),
          destination: PaEss.destination() | nil,
          headway_range: Headway.HeadwayDisplay.headway_range(),
          previous_departure_mins: integer() | nil
        }

  @spec from_headway_message(Content.Message.t(), Content.Message.t()) :: t() | {t(), t()} | nil
  def from_headway_message(
        %Content.Message.Headways.Top{destination: destination},
        %Content.Message.Headways.Bottom{range: range} = msg
      ) do
    case {create(:english, destination, range, msg.prev_departure_mins),
          create(:spanish, destination, range, msg.prev_departure_mins)} do
      {%__MODULE__{} = a1, %__MODULE__{} = a2} -> {a1, a2}
      {%__MODULE__{} = a, nil} -> a
      _ -> nil
    end
  end

  def from_headway_message(top, bottom) do
    Logger.error(
      "message_to_audio_error Audio.VehiclesToDestination: #{inspect(top)}, #{inspect(bottom)}"
    )

    nil
  end

  @spec create(
          Content.Audio.language(),
          PaEss.destination() | nil,
          Headway.HeadwayDisplay.headway_range(),
          integer() | nil
        ) :: t() | nil

  defp create(:english, nil, range, nil) do
    %__MODULE__{
      language: :english,
      destination: nil,
      headway_range: range,
      previous_departure_mins: nil
    }
  end

  defp create(:spanish, nil, _range, nil) do
    nil
  end

  defp create(language, destination, headway_range, previous_departure_mins) do
    if Utilities.valid_destination?(destination, language) and
         not (language == :spanish and !is_nil(previous_departure_mins)) do
      %__MODULE__{
        language: language,
        destination: destination,
        headway_range: headway_range,
        previous_departure_mins: previous_departure_mins
      }
    end
  end

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(%Content.Audio.VehiclesToDestination{
          language: :english,
          destination: nil,
          headway_range: {range_low, range_high},
          previous_departure_mins: nil
        }) do
      {:ad_hoc, {"Trains every #{range_low} to #{range_high} minutes.", :audio}}
    end

    def to_params(
          %Content.Audio.VehiclesToDestination{
            headway_range: {lower_mins, higher_mins},
            previous_departure_mins: nil
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

    def to_params(
          %Content.Audio.VehiclesToDestination{language: :english, headway_range: {x, y}} = audio
        )
        when (x == :up_to or is_integer(x)) and is_integer(y) do
      case PaEss.Utilities.destination_to_ad_hoc_string(audio.destination) do
        {:ok, destination_string} ->
          vehicles_to_destination =
            if audio.destination in [
                 :northbound,
                 :southbound,
                 :eastbound,
                 :westbound,
                 :inbound,
                 :outbound
               ] do
              destination_string <> " trains"
            else
              "Trains to " <> destination_string
            end

          minutes_range =
            case audio.headway_range do
              {:up_to, up_to_mins} -> " up to every #{up_to_mins} minutes."
              {lower_mins, higher_mins} -> " every #{lower_mins} to #{higher_mins} minutes."
            end

          previous_departure =
            if !is_nil(audio.previous_departure_mins) and audio.previous_departure_mins > 0 do
              minutes_word = if audio.previous_departure_mins == 1, do: "minute", else: "minutes"
              "  Previous departure #{audio.previous_departure_mins} #{minutes_word} ago."
            else
              ""
            end

          {:ad_hoc, {vehicles_to_destination <> minutes_range <> previous_departure, :audio}}

        {:error, :unknown} ->
          nil
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
    defp message_id(%{language: :english, destination: :northbound}), do: "183"
    defp message_id(%{language: :english, destination: :southbound}), do: "184"
    defp message_id(%{language: :english, destination: :eastbound}), do: "181"
    defp message_id(%{language: :english, destination: :westbound}), do: "182"
    defp message_id(%{language: :english, destination: :medford_tufts}), do: "196"

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
