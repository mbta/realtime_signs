defmodule Content.Audio.VehiclesToDestination do
  @moduledoc """
  Buses to Chelsea / S. Station arrive every [Number] to [Number] minutes
  """

  @enforce_keys [:destination, :headway_range]
  defstruct @enforce_keys ++ [:route]

  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          headway_range: {non_neg_integer(), non_neg_integer()},
          route: String.t() | nil
        }

  defimpl Content.Audio do
    def to_tts(%Content.Audio.VehiclesToDestination{} = audio) do
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
            destination_text = PaEss.Utilities.destination_to_tts_string(destination)
            "#{destination_text} trains"
        end

      "#{trains} every #{range_low} to #{range_high} minutes."
    end
  end
end
