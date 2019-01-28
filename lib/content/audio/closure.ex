defmodule Content.Audio.Closure do
  @moduledoc """
  Audio message for a station where service is replaced by shuttle buses or suspended entirely.
  """

  @enforce_keys [:alert]
  defstruct @enforce_keys

  @type t ::
          %__MODULE__{
            alert: :shuttles_closed_station | :suspension
          }
          | nil

  @spec from_messages(Content.Message.t(), Content.Message.t()) :: t()
  def from_messages(%Content.Message.Alert.NoService{}, %Content.Message.Alert.UseShuttleBus{}) do
    %Content.Audio.Closure{alert: :shuttles_closed_station}
  end

  def from_messages(%Content.Message.Alert.NoService{}, %Content.Message.Empty{}) do
    %Content.Audio.Closure{alert: :suspension}
  end

  def from_messages(_, _), do: nil

  defimpl Content.Audio do
    def to_params(%Content.Audio.Closure{alert: :shuttles_closed_station}) do
      {"123", [], :audio}
    end

    def to_params(%Content.Audio.Closure{alert: :suspension}) do
      {"456", [], :audio}
    end
  end
end
