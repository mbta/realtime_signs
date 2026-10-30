defmodule Message.ServiceEnded do
  @enforce_keys [:line, :destination]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          line: String.t() | nil
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

    def to_full_page(%Message.ServiceEnded{destination: nil, line: line}) do
      {if(line, do: "No #{line} Line", else: "Station closed"), "Service ended for night"}
    end

    def to_full_page(%Message.ServiceEnded{destination: destination}) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)
      {"Service ended", "No #{headsign} trains"}
    end

    def to_audio(%Message.ServiceEnded{} = message, _multiple?) do
      [%Content.Audio.ServiceEnded{destination: message.destination, line: message.line}]
    end
  end
end
