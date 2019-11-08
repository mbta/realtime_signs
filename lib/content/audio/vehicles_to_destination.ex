defmodule Content.Audio.VehiclesToDestination do
  @moduledoc """
  Buses to Chelsea / S. Station arrive every [Number] to [Number] minutes
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:language, :destination, :next_trip_mins, :later_trip_mins]
  defstruct @enforce_keys ++ [:previous_departure_mins]

  @type t :: %__MODULE__{
          language: Content.Audio.language(),
          destination: PaEss.destination(),
          next_trip_mins: integer(),
          later_trip_mins: integer(),
          previous_departure_mins: integer() | nil
        }

  @spec from_headway_message(Content.Message.t(), Content.Message.t()) :: t() | {t(), t()} | nil
  def from_headway_message(
        %Content.Message.Headways.Top{headsign: headsign},
        %Content.Message.Headways.Bottom{range: range} = msg
      )
      when range != {nil, nil} do
    with {:ok, destination} <- PaEss.Utilities.headsign_to_destination(headsign),
         {x, y} <- get_mins(range) do
      case {create(:english, destination, x, y, msg.prev_departure_mins),
            create(:spanish, destination, x, y, msg.prev_departure_mins)} do
        {%__MODULE__{} = a1, %__MODULE__{} = a2} -> {a1, a2}
        {%__MODULE__{} = a, nil} -> a
        _ -> nil
      end
    else
      _ ->
        Logger.error(
          "message_to_audio_error Audio.VehiclesToDestination: #{inspect(msg)}, #{headsign}"
        )

        nil
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
          PaEss.destination(),
          integer(),
          integer(),
          integer() | nil
        ) :: t() | nil
  defp create(language, destination, next_mins, later_mins, previous_departure_mins) do
    if Utilities.valid_range?(next_mins, language) and
         Utilities.valid_range?(later_mins, language) and
         Utilities.valid_destination?(destination, language) and
         not (language == :spanish and !is_nil(previous_departure_mins)) do
      %__MODULE__{
        language: language,
        destination: destination,
        next_trip_mins: next_mins,
        later_trip_mins: later_mins,
        previous_departure_mins: previous_departure_mins
      }
    end
  end

  defp get_mins({x, nil}), do: {x, x + 2}
  defp get_mins({nil, x}), do: {x, x + 2}
  defp get_mins({x, x}), do: {x, x + 2}
  defp get_mins({x, y}) when x < y, do: {x, y}
  defp get_mins({y, x}), do: {x, y}
  defp get_mins(_), do: :error

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(
          %Content.Audio.VehiclesToDestination{
            next_trip_mins: next_trip_mins,
            later_trip_mins: later_trip_mins,
            previous_departure_mins: nil,
            language: language
          } = audio
        )
        when (later_trip_mins - next_trip_mins <= 10 or language == :spanish) and
               next_trip_mins != later_trip_mins do
      case vars(audio) do
        nil ->
          Logger.warn("no_audio_for_headway_range #{inspect(audio)}")
          nil

        vars ->
          {:canned, {message_id(audio), vars, :audio}}
      end
    end

    def to_params(%Content.Audio.VehiclesToDestination{language: :english} = audio) do
      destination_string = PaEss.Utilities.destination_to_ad_hoc_string(audio.destination)

      vehicles_to_destination =
        if audio.destination in [:northbound, :southbound, :eastbound, :westbound] do
          destination_string <> " trains"
        else
          "Trains to " <> destination_string
        end

      minutes_range =
        cond do
          audio.next_trip_mins == audio.later_trip_mins ->
            " every #{audio.next_trip_mins} minutes."

          audio.later_trip_mins - audio.next_trip_mins <= 10 ->
            " every #{audio.next_trip_mins} to #{audio.later_trip_mins} minutes."

          true ->
            " up to every #{audio.later_trip_mins} minutes."
        end

      previous_departure =
        if audio.previous_departure_mins do
          minutes_word = if audio.previous_departure_mins == 1, do: "minute", else: "minutes"
          "  Previous departure #{audio.previous_departure_mins} #{minutes_word} ago."
        else
          ""
        end

      {:ad_hoc, {vehicles_to_destination <> minutes_range <> previous_departure, :audio}}
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

    defp message_id(%{language: :english, destination: :chelsea}), do: "133"
    defp message_id(%{language: :english, destination: :south_station}), do: "134"
    defp message_id(%{language: :spanish, destination: :chelsea}), do: "150"
    defp message_id(%{language: :spanish, destination: :south_station}), do: "151"

    @spec vars(Content.Audio.VehiclesToDestination.t()) :: [String.t()] | nil
    defp vars(%{language: language, next_trip_mins: next, later_trip_mins: later}) do
      next_trip_var = Utilities.number_var(next, language)
      later_trip_var = Utilities.number_var(later, language)

      if next_trip_var && later_trip_var do
        [next_trip_var, later_trip_var]
      else
        nil
      end
    end
  end
end
