defmodule Content.Audio.BusesToDestination do
  @moduledoc """
  Buses to Chelsea / S. Station arrive every [Number] to [Number] minutes
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:language, :destination, :next_bus_mins, :later_bus_mins]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
    language: :english | :spanish,
    destination: :chelsea | :south_station,
    next_bus_mins: integer(),
    later_bus_mins: integer(),
  }

  @spec from_headway_message(Content.Message.t(), String.t) :: {t() | nil, t() | nil}
  def from_headway_message(%Content.Message.Headways.Bottom{range: range} = msg, dest)
  when range != {nil, nil} do
    with {:ok, destination} <- convert_destination(dest),
         {x, y} <- get_mins(range) do
      {create(:english, destination, x, y), create(:spanish, destination, x, y)}
    else
      _ ->
        Logger.warn("Content.Audio.BusesToDestination.from_headway_message: #{inspect(msg)}, #{dest}")
        {nil, nil}
    end
  end
  def from_headway_message(_msg, _dest) do
    {nil, nil}
  end

  defp create(language, destination, next_mins, later_mins) do
    if Utilities.valid_range?(next_mins, language) and Utilities.valid_range?(later_mins, language) do
      %__MODULE__{
        language: language,
        destination: destination,
        next_bus_mins: next_mins,
        later_bus_mins: later_mins,
      }
    end
  end

  defp convert_destination("Chelsea"), do: {:ok, :chelsea}
  defp convert_destination("South Station"), do: {:ok, :south_station}
  defp convert_destination(_), do: {:error, :unknown_destination}

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
      {:ok, next_var} = Utilities.number_var(next, language)
      {:ok, later_var} = Utilities.number_var(later, language)
      [next_var, later_var]
    end
  end
end
