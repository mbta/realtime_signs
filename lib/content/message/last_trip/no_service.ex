defmodule Content.Message.LastTrip.NoService do
  @enforce_keys [:destination, :page?]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination(),
          page?: boolean()
        }

  defimpl Content.Message do
    def to_string(%Content.Message.LastTrip.NoService{
          destination: destination,
          page?: page?
        }) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)

      if page?,
        do: [
          {Content.Utilities.width_padded_string(
             headsign,
             "No trains",
             24
           ), 6},
          {Content.Utilities.width_padded_string(
             headsign,
             "Svc ended",
             24
           ), 6}
        ],
        else:
          Content.Utilities.width_padded_string(
            headsign,
            "No Svc",
            18
          )
    end
  end
end
