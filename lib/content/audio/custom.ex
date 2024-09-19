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

  @spec from_messages(Content.Message.Custom.t(), Content.Message.t()) :: [t()]
  def from_messages(%Content.Message.Custom{line: :top, message: top}, %Content.Message.Custom{
        line: :bottom,
        message: bottom
      }) do
    audio = "#{top} #{bottom}"

    [%__MODULE__{message: audio}]
  end

  def from_messages(%Content.Message.Custom{line: :top, message: audio}, %Content.Message.Empty{}) do
    [%__MODULE__{message: audio}]
  end

  def from_messages(%Content.Message.Empty{}, %Content.Message.Custom{
        line: :bottom,
        message: audio
      }) do
    [%__MODULE__{message: audio}]
  end

  defimpl Content.Audio do
    def to_params(%Content.Audio.Custom{message: message}) do
      {:ad_hoc, {message, :audio}}
    end

    def to_tts(%Content.Audio.Custom{} = audio) do
      {audio.message, nil}
    end

    def to_logs(%Content.Audio.Custom{}) do
      []
    end
  end
end
