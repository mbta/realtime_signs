defmodule Locations.Location do
  defstruct vehicle_id: nil,
            status: nil,
            stop_id: nil,
            timestamp: nil,
            route_id: nil,
            trip_id: nil,
            consist: [],
            multi_carriage_details: []

  @type t :: %__MODULE__{
          vehicle_id: String.t() | nil,
          status: :incoming_at | :stopped_at | :in_transit_to,
          stop_id: String.t() | nil,
          timestamp: DateTime.t() | nil,
          route_id: String.t() | nil,
          trip_id: String.t() | nil,
          consist: list(),
          multi_carriage_details: list(CarriageDetails.t())
        }
end
