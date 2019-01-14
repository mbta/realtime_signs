defmodule Content.Audio.VehiclesToDestination do
  @moduledoc """
  Buses to Chelsea / S. Station arrive every [Number] to [Number] minutes
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:language, :destination, :next_trip_mins, :later_trip_mins]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          language: Content.Audio.language(),
          destination: Content.Audio.destination(),
          next_trip_mins: integer(),
          later_trip_mins: integer()
        }

  @spec from_headway_message(Content.Message.t(), String.t()) :: {t() | nil, t() | nil}
  def from_headway_message(%Content.Message.Headways.Bottom{range: range} = msg, dest)
      when range != {nil, nil} do
    with {:ok, destination} <- convert_destination(dest),
         {x, y} <- get_mins(range) do
      {create(:english, destination, x, y), create(:spanish, destination, x, y)}
    else
      _ ->
        Logger.warn(
          "Content.Audio.VehiclesToDestination.from_headway_message unable to convert headway message to audio: #{
            inspect(msg)
          }, #{dest}"
        )

        {nil, nil}
    end
  end

  def from_headway_message(_msg, _dest) do
    {nil, nil}
  end

  defp create(language, destination, next_mins, later_mins) do
    if Utilities.valid_range?(next_mins, language) and
         Utilities.valid_range?(later_mins, language) and
         Utilities.valid_destination?(destination, language) do
      %__MODULE__{
        language: language,
        destination: destination,
        next_trip_mins: next_mins,
        later_trip_mins: later_mins
      }
    end
  end

  defp convert_destination("Northbound"), do: {:ok, :northbound}
  defp convert_destination("Southbound"), do: {:ok, :southbound}
  defp convert_destination("Eastbound"), do: {:ok, :eastbound}
  defp convert_destination("Westbound"), do: {:ok, :westbound}
  defp convert_destination("Alewife"), do: {:ok, :alewife}
  defp convert_destination("Ashmont"), do: {:ok, :ashmont}
  defp convert_destination("Braintree"), do: {:ok, :braintree}
  defp convert_destination("Wonderland"), do: {:ok, :wonderland}
  defp convert_destination("Bowdoin"), do: {:ok, :bowdoin}
  defp convert_destination("Forest Hills"), do: {:ok, :forest_hills}
  defp convert_destination("Oak Grove"), do: {:ok, :oak_grove}
  defp convert_destination("Park Sreet"), do: {:ok, :park_street}
  defp convert_destination("Govt Ctr"), do: {:ok, :govt_ctr}
  defp convert_destination("North Station"), do: {:ok, :north_sta}
  defp convert_destination("Lechmere"), do: {:ok, :lechmere}
  defp convert_destination("Riverside"), do: {:ok, :riverside}
  defp convert_destination("Heath St"), do: {:ok, :heath_street}
  defp convert_destination("Boston College"), do: {:ok, :boston_college}
  defp convert_destination("Cleveland Circle"), do: {:ok, :cleveland_circle}
  defp convert_destination("Mattapan"), do: {:ok, :mattapan}
  defp convert_destination("Chelsea"), do: {:ok, :chelsea}
  defp convert_destination("South Station"), do: {:ok, :south_station}
  defp convert_destination(_), do: {:error, :unknown_destination}

  defp get_mins({x, nil}), do: {x, x + 2}
  defp get_mins({nil, x}), do: {x, x + 2}
  defp get_mins({x, x}), do: {x, x + 2}
  defp get_mins({x, y}) when x < y, do: {x, y}
  defp get_mins({y, x}), do: {x, y}
  defp get_mins(_), do: :error

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(audio) do
      {message_id(audio), vars(audio), :audio}
    end

    @spec message_id(Content.Audio.VehiclesToDestination.t()) :: String.t()
    defp message_id(%{language: :english, destination: :boston_college}), do: "642"
    defp message_id(%{language: :english, destination: :cleveland_circle}), do: "643"
    defp message_id(%{language: :english, destination: :riverside}), do: "644"
    defp message_id(%{language: :english, destination: :heath_street}), do: "645"
    defp message_id(%{language: :english, destination: :reservoir}), do: "646"
    defp message_id(%{language: :english, destination: :kenmore}), do: "647"
    defp message_id(%{language: :english, destination: :govt_ctr}), do: "648"
    defp message_id(%{language: :english, destination: :park_street}), do: "649"
    defp message_id(%{language: :english, destination: :north_sta}), do: "650"
    defp message_id(%{language: :english, destination: :lechmere}), do: "651"
    defp message_id(%{language: :english, destination: :ashmont}), do: "654"
    defp message_id(%{language: :english, destination: :braintree}), do: "655"
    defp message_id(%{language: :english, destination: :alewife}), do: "656"
    defp message_id(%{language: :english, destination: :forest_hills}), do: "657"
    defp message_id(%{language: :english, destination: :oak_grove}), do: "658"
    defp message_id(%{language: :english, destination: :bowdoin}), do: "659"
    defp message_id(%{language: :english, destination: :wonderland}), do: "660"
    defp message_id(%{language: :english, destination: :mattapan}), do: "661"
    defp message_id(%{language: :english, destination: :eastbound}), do: "662"
    defp message_id(%{language: :english, destination: :westbound}), do: "663"
    defp message_id(%{language: :english, destination: :northbound}), do: "664"
    defp message_id(%{language: :english, destination: :southbound}), do: "665"

    defp message_id(%{language: :english, destination: :chelsea}), do: "133"
    defp message_id(%{language: :english, destination: :south_station}), do: "134"
    defp message_id(%{language: :spanish, destination: :chelsea}), do: "150"
    defp message_id(%{language: :spanish, destination: :south_station}), do: "151"

    defp vars(%{language: language, next_trip_mins: next, later_trip_mins: later}) do
      [Utilities.number_var(next, language), Utilities.number_var(later, language)]
    end
  end
end
