defmodule Message.Alert do
  @enforce_keys [:route, :destination, :status, :uses_shuttles?, :union_square?]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route: String.t() | nil,
          status: Engine.Alerts.Fetcher.stop_status(),
          uses_shuttles?: boolean(),
          union_square?: boolean()
        }

  defimpl Message do
    @width 24

    defguardp use_shuttle?(message)
              when message.status == :shuttles_closed_station and message.uses_shuttles?

    def to_single_line(%Message.Alert{} = message, :long) when use_shuttle?(message) do
      headsign = PaEss.Utilities.destination_to_sign_string(message.destination)

      [
        {Content.Utilities.width_padded_string(headsign, "no service", @width), 6},
        {Content.Utilities.width_padded_string(headsign, "use shuttle", @width), 6}
      ]
    end

    def to_single_line(%Message.Alert{} = message, :short) when use_shuttle?(message), do: nil

    def to_single_line(%Message.Alert{} = message, :long) do
      headsign = PaEss.Utilities.destination_to_sign_string(message.destination)
      Content.Utilities.width_padded_string(headsign, "no service", 24)
    end

    def to_single_line(%Message.Alert{} = message, :short) do
      headsign = PaEss.Utilities.destination_to_sign_string(message.destination)
      Content.Utilities.width_padded_string(headsign, "no svc", 18)
    end

    def to_full_page(%Message.Alert{} = message) do
      top =
        case {message.route, message.destination} do
          {nil, nil} -> "No train service"
          {route, nil} -> "No #{route} Line"
          {_, destination} -> "No #{PaEss.Utilities.destination_to_sign_string(destination)} svc"
        end

      bottom =
        cond do
          message.union_square? -> "Use Routes 87, 91 or 109"
          use_shuttle?(message) -> "Use shuttle bus"
          true -> ""
        end

      {top, bottom}
    end

    def to_multi_line(%Message.Alert{} = message), do: to_full_page(message)

    def to_audio(%Message.Alert{} = message, _multiple?) do
      [
        %Content.Audio.NoService{
          route: message.route,
          destination: message.destination,
          use_shuttle?: use_shuttle?(message),
          use_routes?: message.union_square?
        }
      ]
    end
  end
end
