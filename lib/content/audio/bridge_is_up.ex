defmodule Content.Audio.BridgeIsUp do
  @moduledoc """
  Buses to Chelsea / S. Station arrive every [Number] to [Number] minutes
  """

  require Logger

  @enforce_keys [:language, :time_estimate_mins]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
    language: :english | :spanish,
    time_estimate_mins: integer() | nil
  }

  @spec create_bridge_messages(integer | nil) :: {t(), t()}
  def create_bridge_messages(minutes) do
    english = %__MODULE__{
      language: :english,
      time_estimate_mins: minutes
    }
    spanish = %{english | language: :spanish}
    {english, spanish}
  end

  defimpl Content.Audio do
    alias PaEss.Utilities

    def to_params(audio) do
      {message_id(audio), vars(audio), :audio_visual}
    end

    defp message_id(%{language: :english, time_estimate_mins: nil}), do: "136"
    defp message_id(%{language: :english, time_estimate_mins: _mins}), do: "135"
    defp message_id(%{language: :spanish, time_estimate_mins: nil}), do: "157"
    defp message_id(%{language: :spanish, time_estimate_mins: _mins}), do: "152"

    defp vars(%{language: _language, time_estimate_mins: nil}), do: []
    defp vars(%{language: language, time_estimate_mins: mins}) do
      [Utilities.number_var(mins, language)]
    end
  end
end
