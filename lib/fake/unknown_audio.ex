defmodule Fake.UnknownAudio do
  defstruct []

  defimpl Content.Audio do
    def to_params(_) do
      nil
    end
  end
end
