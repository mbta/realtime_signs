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
      case Content.Message.to_string(message) do
        pages when is_list(pages) -> Enum.map(pages, fn {_, n} -> n end) |> Enum.sum()
        str when is_binary(str) -> 6
      end
    end
    |> Enum.max()
  end

  @spec destination_for_prediction(String.t(), 0 | 1, String.t()) ::
          {:ok, PaEss.destination()} | {:error, :not_found}
  def destination_for_prediction("Mattapan", 0, _), do: {:ok, :mattapan}
  def destination_for_prediction("Mattapan", 1, _), do: {:ok, :ashmont}
  def destination_for_prediction("Orange", 0, _), do: {:ok, :forest_hills}
  def destination_for_prediction("Orange", 1, _), do: {:ok, :oak_grove}
  def destination_for_prediction("Blue", 0, _), do: {:ok, :bowdoin}
  def destination_for_prediction("Blue", 1, _), do: {:ok, :wonderland}
  def destination_for_prediction("Red", 1, _), do: {:ok, :alewife}

  def destination_for_prediction("Red", 0, last_stop_id)
      when last_stop_id in ["70085", "70086", "70087", "70089", "70091", "70093"],
      do: {:ok, :ashmont}

  def destination_for_prediction("Red", 0, last_stop_id)
      when last_stop_id in [
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
      do: {:ok, :braintree}

  def destination_for_prediction("Red", 0, _), do: {:ok, :southbound}

  def destination_for_prediction(_, 0, "70151"), do: {:ok, :kenmore}
  def destination_for_prediction(_, 0, "71151"), do: {:ok, :kenmore}
  def destination_for_prediction(_, 0, "70202"), do: {:ok, :government_center}
  def destination_for_prediction(_, 0, "70201"), do: {:ok, :government_center}
  def destination_for_prediction(_, 0, "70175"), do: {:ok, :reservoir}
  def destination_for_prediction(_, 0, "70107"), do: {:ok, :boston_college}
  def destination_for_prediction(_, 0, "70237"), do: {:ok, :cleveland_circle}
  def destination_for_prediction(_, 0, "70161"), do: {:ok, :riverside}
  def destination_for_prediction(_, 0, "70260"), do: {:ok, :heath_street}

  def destination_for_prediction(_, 1, "70205"), do: {:ok, :north_station}
  def destination_for_prediction(_, 1, "70511"), do: {:ok, :medford_tufts}
  def destination_for_prediction(_, 1, "70503"), do: {:ok, :union_square}
  def destination_for_prediction(_, 1, "70501"), do: {:ok, :lechmere}
  def destination_for_prediction(_, 1, "70201"), do: {:ok, :government_center}
  def destination_for_prediction(_, 1, "70200"), do: {:ok, :park_street}
  def destination_for_prediction(_, 1, "71199"), do: {:ok, :park_street}
  def destination_for_prediction(_, 1, "70150"), do: {:ok, :kenmore}
  def destination_for_prediction(_, 1, "71150"), do: {:ok, :kenmore}
  def destination_for_prediction(_, 1, "70174"), do: {:ok, :reservoir}

  def destination_for_prediction(_, _, "Government Center-Brattle"), do: {:ok, :government_center}

  def destination_for_prediction("Green-B", 0, _), do: {:ok, :boston_college}
  def destination_for_prediction("Green-C", 0, _), do: {:ok, :cleveland_circle}
  def destination_for_prediction("Green-D", 0, _), do: {:ok, :riverside}
  def destination_for_prediction("Green-E", 0, _), do: {:ok, :heath_street}
  def destination_for_prediction("Green-B", 1, _), do: {:ok, :government_center}
  def destination_for_prediction("Green-C", 1, _), do: {:ok, :government_center}
  def destination_for_prediction("Green-D", 1, _), do: {:ok, :union_square}
  def destination_for_prediction("Green-E", 1, _), do: {:ok, :medford_tufts}

  def destination_for_prediction(_, _, _), do: {:error, :not_found}

  @spec stop_track_number(String.t()) :: track_number() | nil
  def stop_track_number("Alewife-01"), do: 1
  def stop_track_number("Alewife-02"), do: 2
  def stop_track_number("Braintree-01"), do: 1
  def stop_track_number("Braintree-02"), do: 2
  def stop_track_number("Forest Hills-01"), do: 1
  def stop_track_number("Forest Hills-02"), do: 2
  def stop_track_number("Oak Grove-01"), do: 1
  def stop_track_number("Oak Grove-02"), do: 2
  def stop_track_number(_), do: nil

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
      {:train_level, :not_crowded} -> "874"
      {:train_level, :some_crowding} -> "875"
      {:train_level, :crowded} -> "876"
      _ -> "21000"
    end
  end
end
