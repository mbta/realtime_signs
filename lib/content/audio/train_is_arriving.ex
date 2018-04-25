defmodule Content.Audio.TrainIsArriving do
  @moduledoc """
  The next train to [destination] is now arriving.
  """

  @enforce_keys [:destination]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
    destination: :ashmont | :mattapan
  }

  defimpl Content.Audio do
    def to_params(audio) do
      {message_id(audio), [], :audio}
    end

    defp message_id(%{destination: :ashmont}), do: "90129"
    defp message_id(%{destination: :mattapan}), do: "90128"
  end
end
