defmodule Content.Audio.ChelseaBridgeLoweredSoon do
  @moduledoc """
  The Chelsea Street bridge is raised. We expect it to be lowered
  soon. SL3 buses may be delayed, detoured, or turned back.
  """

  @enforce_keys [:language]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
    language: :english | :spanish
  }

  defimpl Content.Audio do
    def to_params(%{language: :english}) do
      {"136", [], :audio_visual}
    end
    def to_params(%{language: :spanish}) do
      {"157", [], :audio_visual}
    end
  end
end
