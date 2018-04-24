defmodule Content.Audio.BusesToDestination do
  @moduledoc """
  Buses to Chelsea / S. Station arrive every [Number] to [Number] minutes
  """

  @enforce_keys [:language, :destination, :next_bus_mins, :later_bus_mins]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
    language: :english | :spanish,
    destination: :chelsea | :south_station,
    next_bus_mins: integer(),
    later_bus_mins: integer(),
  }

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(audio) do
      {message_id(audio), vars(audio)}
    end

    defp message_id(%{language: :english, destination: :chelsea}), do: "133"
    defp message_id(%{language: :english, destination: :south_station}), do: "134"
    defp message_id(%{language: :spanish, destination: :chelsea}), do: "150"
    defp message_id(%{language: :spanish, destination: :south_station}), do: "151"

    defp vars(%{language: language, next_bus_mins: next, later_bus_mins: later}) do
      [Utilities.number_var(next, language), Utilities.number_var(later, language)]
    end
  end
end
