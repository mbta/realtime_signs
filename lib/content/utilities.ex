defmodule Content.Utilities do
  @type track_number :: non_neg_integer()
  @type green_line_branch :: :b | :c | :d | :e

  def width_padded_string(left, right, width) do
    max_left_length = width - (String.length(right) + 1)
    new_left = left |> String.slice(0, max_left_length) |> String.pad_trailing(max_left_length)
    "#{new_left} #{right}"
  end

  @spec content_duration({Content.Message.t(), Content.Message.t()}) :: integer()
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
  def destination_for_prediction(%{route_id: "Mattapan", direction_id: 0}), do: :mattapan
  def destination_for_prediction(%{route_id: "Mattapan", direction_id: 1}), do: :ashmont
  def destination_for_prediction(%{route_id: "Orange", direction_id: 0}), do: :forest_hills
  def destination_for_prediction(%{route_id: "Orange", direction_id: 1}), do: :oak_grove
  def destination_for_prediction(%{route_id: "Blue", direction_id: 0}), do: :bowdoin
  def destination_for_prediction(%{route_id: "Blue", direction_id: 1}), do: :wonderland
  def destination_for_prediction(%{route_id: "Red", direction_id: 1}), do: :alewife

  def destination_for_prediction(%{route_id: "Red", direction_id: 0, destination_stop_id: stop_id})
      when stop_id in ["70085", "70086", "70087", "70089", "70091", "70093"],
      do: :ashmont

  def destination_for_prediction(%{route_id: "Red", direction_id: 0, destination_stop_id: stop_id})
      when stop_id in [
             "70095",
             "70096",
             "70097",
             "70099",
             "70101",
             "70103",
             "70105",
             "Braintree-01",
             "Braintree-02"
           ],
      do: :braintree

  def destination_for_prediction(%{route_id: "Red", direction_id: 0}), do: :southbound

  def destination_for_prediction(%{direction_id: 0, destination_stop_id: "70151"}), do: :kenmore
  def destination_for_prediction(%{direction_id: 0, destination_stop_id: "71151"}), do: :kenmore

  def destination_for_prediction(%{direction_id: 0, destination_stop_id: "70202"}),
    do: :government_center

  def destination_for_prediction(%{direction_id: 0, destination_stop_id: "70201"}),
    do: :government_center

  def destination_for_prediction(%{direction_id: 0, destination_stop_id: "70175"}), do: :reservoir

  def destination_for_prediction(%{direction_id: 0, destination_stop_id: "70107"}),
    do: :boston_college

  def destination_for_prediction(%{direction_id: 0, destination_stop_id: "70237"}),
    do: :cleveland_circle

  def destination_for_prediction(%{direction_id: 0, destination_stop_id: "70161"}), do: :riverside

  def destination_for_prediction(%{direction_id: 0, destination_stop_id: "70260"}),
    do: :heath_street

  def destination_for_prediction(%{direction_id: 1, destination_stop_id: "70205"}),
    do: :north_station

  def destination_for_prediction(%{direction_id: 1, destination_stop_id: "70511"}),
    do: :medford_tufts

  def destination_for_prediction(%{direction_id: 1, destination_stop_id: "70503"}),
    do: :union_square

  def destination_for_prediction(%{direction_id: 1, destination_stop_id: "70501"}), do: :lechmere

  def destination_for_prediction(%{direction_id: 1, destination_stop_id: "70201"}),
    do: :government_center

  def destination_for_prediction(%{direction_id: 1, destination_stop_id: "70200"}),
    do: :park_street

  def destination_for_prediction(%{direction_id: 1, destination_stop_id: "71199"}),
    do: :park_street

  def destination_for_prediction(%{direction_id: 1, destination_stop_id: "70150"}), do: :kenmore
  def destination_for_prediction(%{direction_id: 1, destination_stop_id: "71150"}), do: :kenmore
  def destination_for_prediction(%{direction_id: 1, destination_stop_id: "70174"}), do: :reservoir

  def destination_for_prediction(%{destination_stop_id: "Government Center-Brattle"}),
    do: :government_center

  def destination_for_prediction(%{route_id: "Green-B", direction_id: 0}), do: :boston_college
  def destination_for_prediction(%{route_id: "Green-C", direction_id: 0}), do: :cleveland_circle
  def destination_for_prediction(%{route_id: "Green-D", direction_id: 0}), do: :riverside
  def destination_for_prediction(%{route_id: "Green-E", direction_id: 0}), do: :heath_street
  def destination_for_prediction(%{route_id: "Green-B", direction_id: 1}), do: :government_center
  def destination_for_prediction(%{route_id: "Green-C", direction_id: 1}), do: :government_center
  def destination_for_prediction(%{route_id: "Green-D", direction_id: 1}), do: :union_square
  def destination_for_prediction(%{route_id: "Green-E", direction_id: 1}), do: :medford_tufts

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

  @spec route_branch_letter(String.t()) :: green_line_branch() | nil
  def route_branch_letter("Green-B"), do: :b
  def route_branch_letter("Green-C"), do: :c
  def route_branch_letter("Green-D"), do: :d
  def route_branch_letter("Green-E"), do: :e
  def route_branch_letter(_), do: nil

  def render_datetime_as_time(time),
    do: Calendar.strftime(time, "%I:%M") |> String.replace_leading("0", "")

  def crowding_description_var(crowding_description) do
    case crowding_description do
      {:front, _} -> "870"
      {:back, _} -> "871"
      {:middle, _} -> "872"
      {:front_and_back, _} -> "873"
      {:train_level, :crowded} -> "876"
      _ -> "21000"
    end
  end
end
