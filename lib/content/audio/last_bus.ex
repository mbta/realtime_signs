defmodule Content.Audio.LastBus do
  @moduledoc """
  The last bus to [Chelsea / S. Station] departs at 12:[TIME] AM.
  """

  @enforce_keys [:destination, :minutes]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
    destination: :chelsea | :south_station,
    minutes: integer()
  }

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(audio) do
      {message_id(audio), vars(audio)}
    end

    defp message_id(%{destination: :chelsea}), do: "137"
    defp message_id(%{destination: :south_station}), do: "138"

    defp vars(%{minutes: minutes}) do
      [Utilities.time_var(minutes)]
    end
  end
end
