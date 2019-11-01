defmodule Content.Audio.Closure do
  @moduledoc """
  Audio message for a station where service is replaced by shuttle buses or suspended entirely.
  """

  require Logger

  @enforce_keys [:alert]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          alert: :shuttles_closed_station | :suspension_closed_station
        }

  @spec from_messages(Content.Message.t(), Content.Message.t()) :: t() | nil
  def from_messages(%Content.Message.Alert.NoService{}, %Content.Message.Alert.UseShuttleBus{}) do
    %Content.Audio.Closure{alert: :shuttles_closed_station}
  end

  def from_messages(%Content.Message.Alert.NoService{}, %Content.Message.Empty{}) do
    %Content.Audio.Closure{alert: :suspension_closed_station}
  end

  def from_messages(top, bottom) do
    Logger.error("message_to_audio_error Audio.Closure #{inspect(top)} #{inspect(bottom)}")
    nil
  end

  defimpl Content.Audio do
    def to_params(%Content.Audio.Closure{alert: :shuttles_closed_station}) do
      {:sign_content, {"90131", [], :audio}}
    end

    def to_params(%Content.Audio.Closure{alert: :suspension_closed_station}) do
      {:sign_content, {"90130", [], :audio}}
    end
  end
end
