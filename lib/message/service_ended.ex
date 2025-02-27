defmodule Message.ServiceEnded do
  @enforce_keys [:route, :destination]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          route: String.t() | nil
        }

  defimpl Message do
    def to_single_line(%Message.ServiceEnded{destination: destination}, :long) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)
      Content.Utilities.width_padded_string(headsign, "Svc ended", 24)
    end

    def to_single_line(%Message.ServiceEnded{destination: destination}, :short) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)
      Content.Utilities.width_padded_string(headsign, "No Svc", 18)
    end

    def to_full_page(%Message.ServiceEnded{destination: nil, route: route}) do
      {if(route, do: "No #{route} Line", else: "Station closed"), "Service ended for night"}
    end

    def to_full_page(%Message.ServiceEnded{destination: destination}) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)
      {"Service ended", "No #{headsign} trains"}
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
