defmodule Content.Audio.NoServiceToDestination do
  @moduledoc """
  No service to [destination]
  """

  require Logger

  @enforce_keys [:message]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          message: String.t()
        }

  def from_message(
        %Content.Message.Alert.DestinationNoService{destination: destination} = message
      ) do
    case PaEss.Utilities.destination_to_ad_hoc_string(destination) do
      {:ok, destination} ->
        audio = "No service to #{destination}"

        [%__MODULE__{message: audio}]

      {:error, :unknown} ->
        Logger.error(
          "NoServiceToDestination.from_message unknown destination: #{inspect(message)}"
        )

        []
    end
  end

  def from_message(%Content.Message.Alert.NoServiceUseShuttle{destination: destination} = message) do
    case PaEss.Utilities.destination_to_ad_hoc_string(destination) do
      {:ok, destination} ->
        audio = "No service to #{destination} use shuttle"

        [%__MODULE__{message: audio}]

      {:error, :unknown} ->
        Logger.error(
          "NoServiceToDestination.from_message unknown destination: #{inspect(message)}"
        )

        []
    end
  end

  defimpl Content.Audio do
    def to_params(%Content.Audio.NoServiceToDestination{message: message}) do
      {:ad_hoc, {message, :audio}}
    end
  end
end
