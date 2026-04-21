defmodule Content.Utilities do
  @type track_number :: non_neg_integer()
  @type green_line_branch :: :b | :c | :d | :e

  def width_padded_string(left, right, width) do
    max_left_length = width - (String.length(right) + 1)
    new_left = left |> String.slice(0, max_left_length) |> String.pad_trailing(max_left_length)
    "#{new_left} #{right}"
  end

  @spec content_duration({Content.Message.value(), Content.Message.value()}) :: integer()
  def content_duration({top, bottom}) do
    for message <- [top, bottom] do
      case message do
        pages when is_list(pages) -> Enum.map(pages, fn {_, n} -> n end) |> Enum.sum()
        str when is_binary(str) -> 6
      end
    end
    |> Enum.max()
  end

  @spec destination_for_prediction(Predictions.Prediction.t()) :: PaEss.destination()
  def destination_for_prediction(prediction) do
    RealtimeSigns.station_stop_engine().get_parent_stop(prediction.destination_stop_id)
  end

  @canonical_destinations MapSet.new([
                            {"Red", 0, "place-asmnl"},
                            {"Red", 0, "place-brntn"},
                            {"Red", 1, "place-alfcl"},
                            {"Mattapan", 0, "place-matt"},
                            {"Mattapan", 1, "place-asmnl"},
                            {"Orange", 0, "place-forhl"},
                            {"Orange", 1, "place-ogmnl"},
                            {"Green-B", 0, "place-lake"},
                            {"Green-B", 1, "place-gover"},
                            {"Green-C", 0, "place-clmnl"},
                            {"Green-C", 1, "place-gover"},
                            {"Green-D", 0, "place-river"},
                            {"Green-D", 1, "place-unsqu"},
                            {"Green-E", 0, "place-hsmnl"},
                            {"Green-E", 1, "place-mdftf"},
                            {"Blue", 0, "place-bomnl"},
                            {"Blue", 1, "place-wondl"}
                          ])

  def canonical_destination?(prediction) do
    {prediction.route_id, prediction.direction_id, destination_for_prediction(prediction)} in @canonical_destinations
  end

  @spec stop_track_number(String.t()) :: track_number() | nil
  def stop_track_number("Alewife-01"), do: 1
  def stop_track_number("Alewife-02"), do: 2
  def stop_track_number("Braintree-01"), do: 1
  def stop_track_number("Braintree-02"), do: 2
  def stop_track_number("Forest Hills-01"), do: 1
  def stop_track_number("Forest Hills-02"), do: 2
  def stop_track_number("Oak Grove-01"), do: 1
  def stop_track_number("Oak Grove-02"), do: 2
  def stop_track_number("Union Square-01"), do: 1
  def stop_track_number("Union Square-02"), do: 2
  def stop_track_number(_), do: nil

  @spec stop_platform(String.t()) :: Content.platform() | nil
  def stop_platform("70086"), do: :ashmont
  def stop_platform("70096"), do: :braintree
  def stop_platform(_), do: nil

  def stop_platform_name("70086"), do: "Ashmont"
  def stop_platform_name("70096"), do: "Braintree"

  @spec route_branch_letter(String.t() | nil) :: green_line_branch() | nil
  def route_branch_letter("Green-B"), do: :b
  def route_branch_letter("Green-C"), do: :c
  def route_branch_letter("Green-D"), do: :d
  def route_branch_letter("Green-E"), do: :e
  def route_branch_letter(_), do: nil

  def render_datetime_as_time(time),
    do: Calendar.strftime(time, "%I:%M") |> String.replace_leading("0", "")
end
