defmodule Content.Audio.ServiceEnded do
  alias PaEss.Utilities
  @enforce_keys [:location]
  defstruct @enforce_keys ++ [:destination]

  @type location :: :platform | :station | :direction
  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          location: location()
        }

  def from_message(%Content.Message.LastTrip.StationClosed{}) do
    [%__MODULE__{location: :station}]
  end

  def from_message(%Content.Message.LastTrip.PlatformClosed{destination: destination}) do
    [%__MODULE__{location: :platform, destination: destination}]
  end

  def from_message(%Content.Message.LastTrip.NoService{destination: destination}) do
    [%__MODULE__{location: :direction, destination: destination}]
  end

  defimpl Content.Audio do
    @service_ended "882"
    @station_closed "883"
    @platform_closed "884"

    def to_params(%Content.Audio.ServiceEnded{location: :station}) do
      Utilities.take_message([@station_closed], :audio)
    end

    def to_params(%Content.Audio.ServiceEnded{location: :platform, destination: destination}) do
      case Utilities.destination_var(destination) do
        {:ok, destination_var} ->
          Utilities.take_message([@platform_closed, destination_var, @service_ended], :audio)

        {:error, :unknown} ->
          nil
      end
    end

    def to_params(%Content.Audio.ServiceEnded{location: :direction, destination: destination}) do
      case Utilities.destination_var(destination) do
        {:ok, destination_var} ->
          Utilities.take_message([destination_var, @service_ended], :audio)

        {:error, :unknown} ->
          nil
      end
    end
  end
end