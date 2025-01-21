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
    def to_single_line(
          %Message.Alert{status: :shuttles_closed_station, uses_shuttles?: true} = message
        ) do
      %Content.Message.Alert.NoServiceUseShuttle{
        route: message.route,
        destination: message.destination
      }
    end

    def to_single_line(
          %Message.Alert{status: :shuttles_closed_station, uses_shuttles?: false} = message
        ) do
      %Content.Message.Alert.DestinationNoService{
        route: message.route,
        destination: message.destination
      }
    end

    def to_single_line(%Message.Alert{status: status} = message)
        when status in [:suspension_closed_station, :station_closure] do
      %Content.Message.Alert.DestinationNoService{
        route: message.route,
        destination: message.destination
      }
    end

    def to_full_page(%Message.Alert{union_square?: true} = message) do
      {%Content.Message.Alert.NoService{route: message.route, destination: message.destination},
       %Content.Message.Alert.UseRoutes{}}
    end

    def to_full_page(
          %Message.Alert{status: :shuttles_closed_station, uses_shuttles?: true} = message
        ) do
      {%Content.Message.Alert.NoService{route: message.route, destination: message.destination},
       %Content.Message.Alert.UseShuttleBus{}}
    end

    def to_full_page(
          %Message.Alert{status: :shuttles_closed_station, uses_shuttles?: false} = message
        ) do
      {%Content.Message.Alert.NoService{route: message.route, destination: message.destination},
       %Content.Message.Empty{}}
    end

    def to_full_page(%Message.Alert{status: status} = message)
        when status in [:suspension_closed_station, :station_closure] do
      {%Content.Message.Alert.NoService{route: message.route, destination: message.destination},
       %Content.Message.Empty{}}
    end

    def to_multi_line(%Message.Alert{} = message), do: to_full_page(message)
  end
end
