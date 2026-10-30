defmodule Message.Headway do
  @enforce_keys [:line, :destination, :range]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          range: {non_neg_integer(), non_neg_integer()},
          line: String.t() | nil
        }

  defimpl Message do
    @width 24

    def to_single_line(%Message.Headway{destination: nil, range: {x, y}}, :long) do
      [{"Trains every", 6}, {"#{x} to #{y} min", 6}]
    end

    def to_single_line(%Message.Headway{destination: destination, range: {x, y}}, :long) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)

      [
        {Content.Utilities.width_padded_string(headsign, "trains every", @width), 6},
        {Content.Utilities.width_padded_string(headsign, "#{x} to #{y} min", @width), 6}
      ]
    end

    def to_single_line(%Message.Headway{}, :short), do: nil

    def to_full_page(%Message.Headway{destination: destination, range: {x, y}, line: line}) do
      top =
        case {destination, line} do
          {nil, nil} -> "Trains"
          {nil, "Mattapan"} -> "Mattapan trains"
          {nil, line} -> "#{line} line trains"
          {destination, _} -> "#{PaEss.Utilities.destination_to_sign_string(destination)} trains"
        end

      {top, "Every #{x} to #{y} min"}
    end

    def to_audio(%Message.Headway{} = message, _multiple?) do
      [
        %Content.Audio.VehiclesToDestination{
          destination: message.destination,
          line: message.line,
          headway_range: message.range
        }
      ]
    end
  end
end
