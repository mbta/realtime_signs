defmodule Content.Audio.NoServiceToDestination do
  @moduledoc """
  No service to [destination]
  """

  require Logger

  @enforce_keys [:destination, :use_shuttle]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          use_shuttle: boolean()
        }

  def from_message(%Content.Message.Alert.DestinationNoService{destination: destination}) do
    [%__MODULE__{destination: destination, use_shuttle: false}]
  end

  def from_message(%Content.Message.Alert.NoServiceUseShuttle{destination: destination}) do
    [%__MODULE__{destination: destination, use_shuttle: true}]
  end

  defimpl Content.Audio do
    def to_params(%Content.Audio.NoServiceToDestination{} = audio) do
      {:ad_hoc, {Content.Audio.to_tts(audio), :audio}}
    end

    def to_tts(%Content.Audio.NoServiceToDestination{} = audio) do
      {:ok, destination_text} = PaEss.Utilities.destination_to_ad_hoc_string(audio.destination)
      shuttle = if(audio.use_shuttle, do: " Use shuttle.", else: "")
      "No #{destination_text} service.#{shuttle}"
    end
  end
end
