defmodule Content.Audio.Approaching do
  @moduledoc """
  The next train to [destination] is now approaching
  """

  @enforce_keys [:destination]
  defstruct @enforce_keys ++ [:trip_id, :platform]

  @type t :: %__MODULE__{
          destination: PaEss.terminal_station(),
          trip_id: Predictions.Prediction.trip_id() | nil,
          platform: Content.platform() | nil
        }

  defimpl Content.Audio do
    def to_params(_audio) do
      # TODO: Get the actual message ID(s)
      {"123", [], :audio_visual}
    end
  end
end
