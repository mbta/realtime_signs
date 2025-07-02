defmodule Message.Headway do
  @enforce_keys [:route, :destination, :range]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          destination: PaEss.destination() | nil,
          range: {non_neg_integer(), non_neg_integer()},
          route: String.t() | nil
        }

  defimpl Message do
    @width 24

    def to_single_line(
          %Message.Headway{destination: nil, range: {x, y}, route: "Silver"},
          :long
        ) do
      [{"Silver Line Buses every", 6}, {"#{x} to #{y} min", 6}]
    end

    def to_single_line(
          %Message.Headway{destination: destination, range: {x, y}, route: "Silver"},
          :long
        ) do
      headsign = PaEss.Utilities.destination_to_sign_string(destination)

      [
        {Content.Utilities.width_padded_string(headsign, "buses every", @width), 6},
        {Content.Utilities.width_padded_string(headsign, "#{x} to #{y} min", @width), 6}
      ]
    end

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

    def to_full_page(%Message.Headway{destination: destination, range: {x, y}, route: route}) do
      top =
        case {destination, route} do
          {nil, nil} ->
            "Trains"

          {nil, "Mattapan"} ->
            "Mattapan trains"

          {nil, "Silver"} ->
            "Silver Line buses"

          {nil, route} ->
            "#{route} line trains"

          {destination, "Silver"} ->
            "#{PaEss.Utilities.destination_to_sign_string(destination)} buses"

          {destination, _} ->
            "#{PaEss.Utilities.destination_to_sign_string(destination)} trains"
        end

      {top, "Every #{x} to #{y} min"}
    end

    def to_multi_line(%Message.Headway{} = message), do: to_full_page(message)

    def to_audio(%Message.Headway{} = message, _multiple?) do
      [
        %Content.Audio.VehiclesToDestination{
          destination: message.destination,
          route: message.route,
          headway_range: message.range
        }
      ]
    end
  end
end
