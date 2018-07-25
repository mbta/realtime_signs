defmodule Content.Audio.BridgeIsUp do
  @moduledoc """
  The Chelsea Street bridge is raised.

  We expect it to be lowered soon. / We expect this to last for at least [Number] more minutes.

  SL3 buses may be delayed, detoured, or turned back.
  """

  require Logger
  alias PaEss.Utilities

  @enforce_keys [:language, :time_estimate_mins]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          language: :english | :spanish,
          time_estimate_mins: integer() | nil
        }

  @spec create_bridge_messages(integer | nil) :: {t() | nil, t() | nil}
  def create_bridge_messages(minutes) do
    {create(:english, minutes), create(:spanish, minutes)}
  end

  defp create(language, nil) do
    %__MODULE__{language: language, time_estimate_mins: nil}
  end

  defp create(language, minutes) do
    if Utilities.valid_range?(minutes, language) do
      %__MODULE__{language: language, time_estimate_mins: minutes}
    end
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
