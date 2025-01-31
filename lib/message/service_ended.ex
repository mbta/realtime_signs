defmodule Message.ServiceEnded do
  @enforce_keys [:route, :destination]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          route: String.t() | nil
        }

  defimpl Message do
    def to_single_line(%Message.ServiceEnded{route: route, destination: destination}) do
      %Content.Message.LastTrip.NoService{destination: destination, route: route}
    end

    def to_full_page(%Message.ServiceEnded{destination: nil, route: route}) do
      {%Content.Message.LastTrip.StationClosed{route: route},
       %Content.Message.LastTrip.ServiceEnded{destination: nil}}
    end

    def to_full_page(%Message.ServiceEnded{destination: destination}) do
      {%Content.Message.LastTrip.PlatformClosed{destination: destination},
       %Content.Message.LastTrip.ServiceEnded{destination: destination}}
    end

    def to_multi_line(%Message.ServiceEnded{} = message), do: to_full_page(message)

    def to_audio(%Message.ServiceEnded{} = message, multiple?) do
      [
        %Content.Audio.ServiceEnded{
          destination: message.destination,
          route: message.route,
          location:
            case {message.destination, multiple?} do
              {nil, _} -> :station
              {_, true} -> :direction
              {_, false} -> :platform
            end
        }
      ]
    end
  end
end
