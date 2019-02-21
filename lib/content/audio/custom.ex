defmodule Content.Audio.Custom do
  @moduledoc """
  Reads custom text from the PIOs
  """

  require Logger

  @enforce_keys [:message]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          message: String.t()
        }

  @spec from_messages(Content.Message.Custom.t(), Content.Message.t()) :: t() | nil
  def from_messages(%Content.Message.Custom{line: :top, message: top}, %Content.Message.Custom{
        line: :bottom,
        message: bottom
      }) do
    audio = "#{top} #{bottom}"

    %__MODULE__{
      message: audio
    }
  end

  def from_messages(%Content.Message.Custom{line: :top, message: audio}, %Content.Message.Empty{}) do
    %__MODULE__{
      message: audio
    }
  end

  def from_messages(%Content.Message.Empty{}, %Content.Message.Custom{
        line: :bottom,
        message: audio
      }) do
    %__MODULE__{
      message: audio
    }
  end

  def from_message(m1, m2) do
    Logger.error("message_to_audio_error Audio.Custom: #{inspect(m1)}, #{inspect(m2)}")
    nil
  end
end
