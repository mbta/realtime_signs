defmodule Content.Audio.BusesToDestination do
  @moduledoc """
  Buses to Chelsea / S. Station arrive every [Number] to [Number] minutes
  """

  require Logger

  @enforce_keys [:language, :destination, :next_bus_mins, :later_bus_mins]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
    language: :english | :spanish,
    destination: :chelsea | :south_station,
    next_bus_mins: integer(),
    later_bus_mins: integer(),
  }

  @spec from_headway_message(Content.Message.t(), String.t) :: t() | nil
  def from_headway_message(msg, dest) do
    with %Content.Message.Headways.Bottom{range: range} <- msg,
         {:ok, destination} <- convert_destination(dest),
         {x, y} <- get_mins(range) do
      english = %__MODULE__{
        language: :english,
        destination: destination,
        next_bus_mins: x,
        later_bus_mins: y,
      }
      spanish = %{english | language: :spanish}
      {english, spanish}
    else
      _ ->
        Logger.warn("Content.Audio.BusesToDestination.from_headway_message: #{inspect(msg)}, #{dest}")
        nil
    end
  end

  defp convert_destination("Chelsea"), do: {:ok, :chelsea}
  defp convert_destination("South Station"), do: {:ok, :south_station}
  defp convert_destination(_), do: {:error, :unknown_destination}

  defp get_mins({nil, nil}), do: :nil
  defp get_mins({x, nil}), do: {x, x+2}
  defp get_mins({nil, x}), do: {x, x+2}
  defp get_mins({x, x}), do: {x, x+2}
  defp get_mins({x, y}) when x < y, do: {x, y}
  defp get_mins({y, x}), do: {x, y}
  defp get_mins(_), do: :error

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(audio) do
      {message_id(audio), vars(audio), :audio}
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
