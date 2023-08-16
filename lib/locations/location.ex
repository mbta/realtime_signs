defmodule Locations do
  defmodule CarriageDetails do
    defstruct label: nil,
              occupancy_status: nil,
              occupancy_percentage: nil,
              carriage_sequence: nil

    @type t :: %__MODULE__{
            label: String.t(),
            occupancy_status:
              :many_seats_available
              | :few_seats_available
              | :standing_room_only
              | :crushed_standing_room_only
              | :full,
            occupancy_percentage: non_neg_integer(),
            carriage_sequence: non_neg_integer()
          }
  end

  defmodule Location do
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
end
