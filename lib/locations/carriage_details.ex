defmodule Locations.CarriageDetails do
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
