defmodule Content.Message.LastTrip.NoService do
  @enforce_keys [:destination, :line]
  defstruct @enforce_keys ++ [:route]

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          route: String.t() | nil,
          line: :top | :bottom
        }

  defimpl Content.Message do
    def to_string(%Content.Message.LastTrip.NoService{
          destination: destination,
          line: line
        }) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)

      if line == :bottom,
        do:
          Content.Utilities.width_padded_string(
            headsign,
            "Svc ended",
            24
          ),
        else:
          Content.Utilities.width_padded_string(
            headsign,
            "No Svc",
            18
          )
    end
  end
end
