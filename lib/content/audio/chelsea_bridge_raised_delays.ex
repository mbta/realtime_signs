defmodule Content.Audio.ChelseaBridgeRaisedDelays do
  @moduledoc """
  The Chelsea Street bridge is raised. We expect this to last for at least
  [Number] more minutes. SL3 buses may be delayed, detoured, or turned back.
  """

  @enforce_keys [:language, :delay_minutes]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
    language: :english | :spanish,
    delay_minutes: integer(),
  }

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(audio) do
      {message_id(audio), vars(audio), :audio_visual}
    end

    defp message_id(%{language: :english}), do: "135"
    defp message_id(%{language: :spanish}), do: "152"

    defp vars(%{language: language, delay_minutes: mins}) do
      [Utilities.number_var(mins, language)]
    end
  end
end
