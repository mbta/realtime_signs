defmodule Content.Audio.ChelseaBridgeLoweredSoon do
  @moduledoc """
  The Chelsea Street bridge is raised. We expect it to be lowered
  soon. SL3 buses may be delayed, detoured, or turned back.
  """

  defstruct []

  @type t :: %__MODULE__{}

  defimpl Content.Audio do
    def to_params(_audio) do
      {"136", []}
    end
  end
end
